// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";

/// @title Gas calculation utilities
library GasCalculations {
    using GasCalculations for uint256;

    /// @notice Calculate savings percentage in basis points
    /// @param originalCost Original execution cost
    /// @param optimizedCost Optimized execution cost
    /// @return savingsPercentageBPS Savings percentage in basis points
    function calculateSavingsPercent(uint256 originalCost, uint256 optimizedCost)
        internal
        pure
        returns (uint256 savingsPercentageBPS)
    {
        if (optimizedCost >= originalCost) return 0;
        return ((originalCost - optimizedCost) * Constants.BASIS_POINTS_DENOMINATOR) / originalCost;
    }

    /// @notice Calculate absolute savings
    /// @param originalCost Original execution cost
    /// @param optimizedCost Optimized execution cost
    /// @return absoluteSavings Absolute savings amount
    function calculateAbsoluteSavings(uint256 originalCost, uint256 optimizedCost)
        internal
        pure
        returns (uint256 absoluteSavings)
    {
        if (optimizedCost >= originalCost) return 0;
        return originalCost - optimizedCost;
    }

    /// @notice Check if savings meet threshold requirements
    /// @param originalCost Original execution cost
    /// @param optimizedCost Optimized execution cost
    /// @param minSavingsThresholdBPS Minimum savings threshold in basis points
    /// @param minAbsoluteSavingsUSD Minimum absolute savings in USD
    /// @return meetsThreshold True if savings meet both threshold requirements
    function meetsSavingsThreshold(
        uint256 originalCost,
        uint256 optimizedCost,
        uint256 minSavingsThresholdBPS,
        uint256 minAbsoluteSavingsUSD
    ) internal pure returns (bool meetsThreshold) {
        uint256 savingsPercentageBPS = calculateSavingsPercent(originalCost, optimizedCost);
        uint256 absoluteSavings = calculateAbsoluteSavings(originalCost, optimizedCost);

        return savingsPercentageBPS >= minSavingsThresholdBPS && absoluteSavings >= minAbsoluteSavingsUSD;
    }

    /// @notice Calculate gas cost with safety margin
    /// @param baseGasCost Base gas cost
    /// @param safetyMarginBPS Safety margin in basis points
    /// @return adjustedGasCost Gas cost with safety margin applied
    function applyGasSafetyMargin(uint256 baseGasCost, uint256 safetyMarginBPS)
        internal
        pure
        returns (uint256 adjustedGasCost)
    {
        if (safetyMarginBPS == 0) return baseGasCost;
        return baseGasCost + (baseGasCost * safetyMarginBPS) / Constants.BASIS_POINTS_DENOMINATOR;
    }

    /// @notice Estimate gas usage for basic ERC20 transfer
    /// @return gasUsage Estimated gas usage
    function estimateTransferGas() internal pure returns (uint256 gasUsage) {
        return 21000; // Standard ETH transfer gas cost
    }

    /// @notice Estimate gas usage for ERC20 token transfer
    /// @return gasUsage Estimated gas usage
    function estimateTokenTransferGas() internal pure returns (uint256 gasUsage) {
        return 65000; // Typical ERC20 transfer gas cost
    }

    /// @notice Estimate gas usage for Uniswap V4 swap
    /// @return gasUsage Estimated gas usage
    function estimateSwapGas() internal pure returns (uint256 gasUsage) {
        return 120000; // Estimated V4 swap gas cost
    }

    /// @notice Estimate gas usage for bridge transaction
    /// @return gasUsage Estimated gas usage
    function estimateBridgeGas() internal pure returns (uint256 gasUsage) {
        return 150000; // Estimated bridge transaction gas cost
    }

    /// @notice Calculate total gas usage for cross-chain swap
    /// @param includeReturn Whether to include return bridge gas
    /// @return totalGasUsage Total estimated gas usage
    function calculateCrossChainGasUsage(bool includeReturn) internal pure returns (uint256 totalGasUsage) {
        uint256 baseGas = estimateBridgeGas() + estimateSwapGas();
        if (includeReturn) {
            baseGas += estimateBridgeGas();
        }
        return baseGas;
    }

    /// @notice Calculate total gas usage for cross-chain swap with custom values
    /// @param sourceGas Gas usage on source chain
    /// @param destGas Gas usage on destination chain  
    /// @param bridgeGas Gas usage for bridge transaction
    /// @return totalGasUsage Total estimated gas usage
    function calculateCombinedGasUsage(uint256 sourceGas, uint256 destGas, uint256 bridgeGas) internal pure returns (uint256 totalGasUsage) {
        return sourceGas + destGas + bridgeGas;
    }

    /// @notice Validate gas price is within acceptable bounds
    /// @param gasPrice Gas price to validate
    /// @return isValid True if gas price is valid
    function validateGasPrice(uint256 gasPrice) internal pure returns (bool isValid) {
        return gasPrice >= Constants.MIN_GAS_PRICE && gasPrice <= Constants.MAX_GAS_PRICE;
    }

    /// @notice Calculate gas cost in Wei
    /// @param gasUsage Gas usage amount
    /// @param gasPrice Gas price in gwei
    /// @return gasCostWei Gas cost in Wei
    function calculateGasCostWei(uint256 gasUsage, uint256 gasPrice) internal pure returns (uint256 gasCostWei) {
        return gasUsage * gasPrice;
    }

    /// @notice Convert basis points to percentage (for display)
    /// @param basisPoints Value in basis points
    /// @return percentage Percentage value (2 decimal places)
    function basisPointsToPercentage(uint256 basisPoints) internal pure returns (uint256 percentage) {
        return (basisPoints * 100) / Constants.BASIS_POINTS_DENOMINATOR;
    }

    /// @notice Convert percentage to basis points
    /// @param percentage Percentage value
    /// @return basisPoints Value in basis points
    function percentageToBasisPoints(uint256 percentage) internal pure returns (uint256 basisPoints) {
        return (percentage * Constants.BASIS_POINTS_DENOMINATOR) / 100;
    }
}