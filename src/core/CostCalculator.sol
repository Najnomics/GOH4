// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICostCalculator} from "../interfaces/ICostCalculator.sol";
import {IGasPriceOracle} from "../interfaces/IGasPriceOracle.sol";
import {IChainlinkAggregator} from "../interfaces/external/IChainlinkAggregator.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";
import {ChainUtils} from "../libraries/ChainUtils.sol";
import {GasCalculations} from "../libraries/GasCalculations.sol";

/// @title Cost Calculator for comprehensive cost analysis
contract CostCalculator is ICostCalculator, Ownable {
    using ChainUtils for uint256;
    using GasCalculations for uint256;

    IGasPriceOracle public gasPriceOracle;
    IChainlinkAggregator public chainlinkIntegration;
    
    CostParameters public costParameters;
    
    constructor(
        address initialOwner,
        address _gasPriceOracle,
        address _chainlinkIntegration
    ) Ownable(initialOwner) {
        gasPriceOracle = IGasPriceOracle(_gasPriceOracle);
        chainlinkIntegration = IChainlinkAggregator(_chainlinkIntegration);
        
        // Initialize default cost parameters
        costParameters = CostParameters({
            baseBridgeFeeUSD: 2e18, // $2 USD
            bridgeFeePercentageBPS: 10, // 0.1%
            maxSlippageBPS: 50, // 0.5%
            mevProtectionFeeBPS: 5, // 0.05%
            gasEstimationMultiplier: 12000 // 1.2x (120% in basis points)
        });
    }

    /// @inheritdoc ICostCalculator
    function calculateTotalCost(CostParams calldata params) external view override returns (TotalCost memory) {
        ChainUtils.validateChainId(params.chainId);
        
        uint256 gasCostUSD = calculateGasCostUSD(params.chainId, params.gasLimit);
        uint256 bridgeFeeUSD = 0;
        uint256 slippageCostUSD = 0;
        uint256 executionTime = 0;
        
        // Add bridge fee if cross-chain
        uint256 currentChainId = block.chainid;
        if (params.chainId != currentChainId) {
            bridgeFeeUSD = calculateBridgeFeeUSD(params.tokenIn, params.amountIn, params.chainId);
            executionTime = currentChainId.getBridgeTime(params.chainId);
        }
        
        // Calculate slippage cost
        slippageCostUSD = estimateSlippageCost(params.tokenIn, params.tokenOut, params.amountIn, params.chainId);
        
        uint256 totalCostUSD = gasCostUSD + bridgeFeeUSD + slippageCostUSD;
        
        return TotalCost({
            gasCostUSD: gasCostUSD,
            bridgeFeeUSD: bridgeFeeUSD,
            slippageCostUSD: slippageCostUSD,
            totalCostUSD: totalCostUSD,
            executionTime: executionTime
        });
    }

    /// @inheritdoc ICostCalculator
    function findOptimalChain(OptimizationParams calldata params) external view override returns (
        uint256 chainId,
        uint256 expectedSavingsUSD
    ) {
        uint256[] memory supportedChains = ChainUtils.getSupportedChains();
        uint256 currentChainId = block.chainid;
        
        // Calculate cost on current chain
        TotalCost memory currentCost = this.calculateTotalCost(CostParams({
            chainId: currentChainId,
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            amountIn: params.amountIn,
            gasLimit: GasCalculations.estimateSwapGas(),
            user: msg.sender,
            gasUsed: GasCalculations.estimateSwapGas(),
            gasPrice: tx.gasprice
        }));
        
        uint256 bestChainId = currentChainId;
        uint256 bestCost = currentCost.totalCostUSD;
        
        // Check costs on other chains
        for (uint256 i = 0; i < supportedChains.length; i++) {
            uint256 testChainId = supportedChains[i];
            
            // Skip current chain and excluded chains
            if (testChainId == currentChainId || _isChainExcluded(testChainId, params.excludeChains)) {
                continue;
            }
            
            TotalCost memory testCost = this.calculateTotalCost(CostParams({
                chainId: testChainId,
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                amountIn: params.amountIn,
                gasLimit: GasCalculations.calculateCrossChainGasUsage(true),
                user: msg.sender,
                gasUsed: GasCalculations.calculateCrossChainGasUsage(true),
                gasPrice: tx.gasprice
            }));
            
            // Check if bridge time is acceptable
            if (params.maxBridgeTime > 0 && testCost.executionTime > params.maxBridgeTime) {
                continue;
            }
            
            if (testCost.totalCostUSD < bestCost) {
                bestCost = testCost.totalCostUSD;
                bestChainId = testChainId;
            }
        }
        
        uint256 savings = currentCost.totalCostUSD > bestCost ? currentCost.totalCostUSD - bestCost : 0;
        
        // Check if savings meet thresholds
        bool meetsThreshold = currentCost.totalCostUSD.meetsSavingsThreshold(
            bestCost,
            params.minSavingsThresholdBPS,
            params.minAbsoluteSavingsUSD
        );
        
        if (!meetsThreshold) {
            return (currentChainId, 0);
        }
        
        return (bestChainId, savings);
    }

    /// @inheritdoc ICostCalculator
    function calculateGasCostUSD(uint256 chainId, uint256 gasLimit) public view override returns (uint256) {
        uint256 gasPriceUSD = gasPriceOracle.getGasPriceUSD(chainId);
        
        // Apply safety margin - gasEstimationMultiplier is in basis points
        uint256 adjustedGasLimit = gasLimit;
        if (costParameters.gasEstimationMultiplier > Constants.BASIS_POINTS_DENOMINATOR) {
            uint256 safetyMarginBPS = costParameters.gasEstimationMultiplier - Constants.BASIS_POINTS_DENOMINATOR;
            adjustedGasLimit = gasLimit.applyGasSafetyMargin(safetyMarginBPS);
        }
        
        return (adjustedGasLimit * gasPriceUSD) / 1e9; // Convert from gwei to full units
    }

    /// @inheritdoc ICostCalculator
    function calculateBridgeFeeUSD(address token, uint256 amount, uint256 destinationChain) public view override returns (uint256) {
        uint256 tokenAmountUSD = convertToUSD(token, amount);
        uint256 percentageFee = (tokenAmountUSD * costParameters.bridgeFeePercentageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
        
        return costParameters.baseBridgeFeeUSD + percentageFee;
    }

    /// @inheritdoc ICostCalculator
    function estimateSlippageCost(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 chainId
    ) public view override returns (uint256) {
        uint256 tokenAmountUSD = convertToUSD(tokenIn, amountIn);
        return (tokenAmountUSD * costParameters.maxSlippageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
    }

    /// @inheritdoc ICostCalculator
    function updateCostParameters(CostParameters calldata newParams) external override onlyOwner {
        // Validate parameters
        if (newParams.bridgeFeePercentageBPS > 1000) { // Max 10%
            revert("Bridge fee percentage too high");
        }
        if (newParams.maxSlippageBPS > 1000) { // Max 10%
            revert("Max slippage too high");
        }
        if (newParams.mevProtectionFeeBPS > 500) { // Max 5%
            revert("MEV protection fee too high");
        }
        if (newParams.gasEstimationMultiplier > 30000 || newParams.gasEstimationMultiplier < 10000) { // 1x to 3x
            revert("Gas estimation multiplier out of range");
        }
        
        costParameters = newParams;
    }

    /// @inheritdoc ICostCalculator
    function updateTokenPriceFeed(address token, address priceFeed) external override onlyOwner {
        chainlinkIntegration.addPriceFeed(token, priceFeed, 8 hours);
    }

    /// @inheritdoc ICostCalculator
    function convertToUSD(address token, uint256 amount) public view override returns (uint256) {
        return chainlinkIntegration.convertToUSD(token, amount);
    }

    /// @inheritdoc ICostCalculator
    function isCostCalculationReliable(uint256 chainId) external view override returns (bool) {
        return !gasPriceOracle.isGasPriceStale(chainId) && chainId.isSupportedChain();
    }

    function _isChainExcluded(uint256 chainId, uint256[] memory excludeChains) private pure returns (bool) {
        for (uint256 i = 0; i < excludeChains.length; i++) {
            if (excludeChains[i] == chainId) {
                return true;
            }
        }
        return false;
    }

    // Additional utility functions expected by tests
    function calculateSlippageCost(uint256 amount, uint256 slippageBPS) external pure returns (uint256) {
        return (amount * slippageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
    }

    function calculateMEVProtectionFee(uint256 amount, uint256 mevFeeBPS) external pure returns (uint256) {
        return (amount * mevFeeBPS) / Constants.BASIS_POINTS_DENOMINATOR;
    }

    function isChainSupported(uint256 chainId) external pure returns (bool) {
        return ChainUtils.isSupportedChain(chainId);
    }

    function getCostParameters() external view returns (CostParameters memory) {
        return costParameters;
    }

    // Admin functions
    function updateChainlinkIntegration(address newChainlinkIntegration) external onlyOwner {
        chainlinkIntegration = IChainlinkAggregator(newChainlinkIntegration);
    }
}