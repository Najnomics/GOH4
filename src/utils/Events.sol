// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Event definitions for Gas Optimization Hook
library Events {
    // Hook events
    event SwapOptimized(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 originalChainId,
        uint256 optimizedChainId,
        uint256 savingsUSD
    );

    event SwapExecutedLocally(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        string reason
    );

    // Gas price oracle events
    event GasPriceUpdated(uint256 indexed chainId, uint256 newGasPrice, uint256 timestamp);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event GasPriceOracleConfigured(uint256[] chainIds, address[] priceFeeds);

    // Cross-chain events
    event CrossChainSwapInitiated(
        bytes32 indexed swapId,
        address indexed user,
        uint256 sourceChain,
        uint256 destinationChain,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    );

    event CrossChainSwapCompleted(
        bytes32 indexed swapId,
        address indexed user,
        uint256 amountOut,
        uint256 totalSavingsUSD
    );

    event BridgeInitiated(
        bytes32 indexed bridgeId,
        address indexed token,
        uint256 amount,
        uint256 destinationChain,
        uint256 bridgeFee
    );

    // Configuration events
    event ConfigurationUpdated(
        uint256 minSavingsThresholdBPS,
        uint256 minAbsoluteSavingsUSD,
        uint256 maxBridgeTime
    );

    event EmergencyPauseToggled(bool isPaused, address indexed admin);
    event ChainConfigUpdated(uint256 indexed chainId, bool enabled, uint256 maxGasPrice);

    // Cost calculation events
    event CostCalculated(
        uint256 indexed chainId,
        address token,
        uint256 amount,
        uint256 totalCostUSD,
        uint256 gasCostUSD,
        uint256 bridgeFeeUSD
    );

    // Token mapping events
    event TokenMappingUpdated(
        address indexed localToken,
        uint256 indexed chainId,
        address remoteToken
    );

    // Safety events
    event CircuitBreakerTriggered(uint256 indexed chainId, string reason);
    event MEVDetected(address indexed user, bytes32 indexed txHash, uint256 frontrunAmount);
}