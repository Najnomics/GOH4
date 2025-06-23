// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Interface for Cost Calculator
interface ICostCalculator {
    struct CostParams {
        uint256 chainId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 gasLimit;
        address user;
    }

    struct TotalCost {
        uint256 gasCostUSD;
        uint256 bridgeFeeUSD;
        uint256 slippageCostUSD;
        uint256 totalCostUSD;
        uint256 executionTime;
    }

    struct OptimizationParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minSavingsThresholdBPS;
        uint256 minAbsoluteSavingsUSD;
        uint256 maxBridgeTime;
        uint256[] excludeChains;
    }

    struct CostParameters {
        uint256 baseBridgeFeeUSD;
        uint256 bridgeFeePercentageBPS;
        uint256 maxSlippageBPS;
        uint256 mevProtectionFeeBPS;
        uint256 gasEstimationMultiplier;
    }

    // Core calculation functions
    function calculateTotalCost(CostParams calldata params) external view returns (TotalCost memory);
    function findOptimalChain(OptimizationParams calldata params) external view returns (
        uint256 chainId,
        uint256 expectedSavingsUSD
    );

    // Individual cost components
    function calculateGasCostUSD(uint256 chainId, uint256 gasLimit) external view returns (uint256);
    function calculateBridgeFeeUSD(address token, uint256 amount, uint256 destinationChain) external view returns (uint256);
    function estimateSlippageCost(address tokenIn, address tokenOut, uint256 amountIn, uint256 chainId) external view returns (uint256);

    // Configuration functions
    function updateCostParameters(CostParameters calldata newParams) external;
    function updateTokenPriceFeed(address token, address priceFeed) external;

    // Utility functions
    function convertToUSD(address token, uint256 amount) external view returns (uint256);
    function isCostCalculationReliable(uint256 chainId) external view returns (bool);
}