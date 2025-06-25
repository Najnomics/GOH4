// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title Interface for Gas Optimization Hook
interface IGasOptimizationHook {
    struct OptimizationQuote {
        uint256 originalChainId;
        uint256 optimizedChainId;
        uint256 originalCostUSD;
        uint256 optimizedCostUSD;
        uint256 savingsUSD;
        uint256 savingsPercentageBPS;
        uint256 estimatedBridgeTime;
        bool shouldOptimize;
    }

    struct UserPreferences {
        uint256 minSavingsThresholdBPS;
        uint256 minAbsoluteSavingsUSD;
        uint256 maxAcceptableBridgeTime;
        bool enableCrossChainOptimization;
        bool enableUSDDisplay;
    }

    struct SwapContext {
        address user;
        PoolKey poolKey;
        SwapParams swapParams;
        uint256 currentChainId;
        bytes hookData;
    }

    // Main hook functions
    function getOptimizationQuote(
        SwapParams calldata params,
        PoolKey calldata key
    ) external view returns (OptimizationQuote memory);

    function setUserPreferences(UserPreferences calldata preferences) external;
    function getUserPreferences(address user) external view returns (UserPreferences memory);

    // Configuration functions
    function updateSystemConfiguration(
        uint256 minSavingsThresholdBPS,
        uint256 minAbsoluteSavingsUSD,
        uint256 maxBridgeTime
    ) external;

    function pauseHook(bool pause) external;
    function isHookPaused() external view returns (bool);

    // Analytics functions
    function getUserSavings(address user) external view returns (uint256 totalSavingsUSD);
    function getSystemMetrics() external view returns (
        uint256 totalSwapsOptimized,
        uint256 totalSavingsUSD,
        uint256 averageSavingsPercentage
    );
}