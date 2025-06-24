// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ICostCalculator} from "../interfaces/ICostCalculator.sol";
import {IGasPriceOracle} from "../interfaces/IGasPriceOracle.sol";
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
    
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    CostParameters public costParameters;
    
    constructor(
        address initialOwner,
        address _gasPriceOracle
    ) Ownable(initialOwner) {
        gasPriceOracle = IGasPriceOracle(_gasPriceOracle);
        
        // Initialize default cost parameters
        costParameters = CostParameters({
            baseBridgeFeeUSD: 2e18, // $2 USD
            bridgeFeePercentageBPS: 10, // 0.1%
            maxSlippageBPS: 50, // 0.5%
            mevProtectionFeeBPS: 5, // 0.05%
            gasEstimationMultiplier: 120 // 1.2x safety margin
        });
        
        _initializeTokenPriceFeeds();
    }

    /// @inheritdoc ICostCalculator
    function calculateTotalCost(CostParams calldata params) external view override returns (TotalCost memory) {
        params.chainId.validateChainId();
        
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
            user: msg.sender
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
                user: msg.sender
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
        uint256 adjustedGasLimit = gasLimit.applyGasSafetyMargin(
            costParameters.gasEstimationMultiplier - Constants.BASIS_POINTS_DENOMINATOR
        );
        
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
        costParameters = newParams;
    }

    /// @inheritdoc ICostCalculator
    function updateTokenPriceFeed(address token, address priceFeed) external override onlyOwner {
        if (token == address(0) || priceFeed == address(0)) {
            revert Errors.ZeroAddress();
        }
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    /// @inheritdoc ICostCalculator
    function convertToUSD(address token, uint256 amount) public view override returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        if (address(priceFeed) == address(0)) {
            revert Errors.InvalidPriceFeed();
        }
        
        (, int256 price, , uint256 updatedAt,) = priceFeed.latestRoundData();
        
        if (block.timestamp - updatedAt > Constants.GAS_PRICE_STALENESS_THRESHOLD) {
            revert Errors.PriceFeedStale();
        }
        
        // Convert price from Chainlink format (8 decimals) to 18 decimals
        uint256 adjustedPrice = uint256(price) * 1e10;
        
        // Assume token has 18 decimals for simplicity
        return (amount * adjustedPrice) / 1e18;
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

    function _initializeTokenPriceFeeds() private {
        // Initialize with mainnet Chainlink price feeds
        // WETH - ETH/USD
        tokenPriceFeeds[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        // USDC - USDC/USD  
        tokenPriceFeeds[0xa0b86A33E6C4B4C2Cc6c1c4CdbBD0d8C7B4e5d2A] = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        // USDT - USDT/USD
        tokenPriceFeeds[0xdAC17F958D2ee523a2206206994597C13D831ec7] = AggregatorV3Interface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    }
}