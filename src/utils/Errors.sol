// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Custom error definitions for Gas Optimization Hook
library Errors {
    // Hook errors
    error InvalidPoolKey();
    error InvalidSwapParams();
    error UnauthorizedSender();
    error HookNotInitialized();
    error InvalidHookData();

    // Gas price oracle errors
    error StaleGasPrice();
    error InvalidChainId();
    error InvalidGasPrice();
    error OracleUpdateFailed();
    error UnauthorizedKeeper();

    // Cost calculation errors
    error InvalidCostParams();
    error CalculationOverflow();
    error InvalidPriceFeed();
    error PriceFeedStale();

    // Cross-chain errors
    error InvalidBridgeParams();
    error BridgeTransactionFailed();
    error CrossChainSwapFailed();
    error InvalidDestinationChain();
    error BridgeTimeout();
    error InsufficientBridgeLiquidity();

    // Configuration errors
    error InvalidConfiguration();
    error ConfigurationLocked();
    error InvalidThreshold();
    error InvalidTimelock();

    // Token mapping errors
    error UnsupportedToken();
    error InvalidTokenMapping();
    error TokenNotBridgeable();

    // Safety errors
    error EmergencyPauseActive();
    error CircuitBreakerTriggered();
    error ExceedsMaxSlippage();
    error MEVDetected();

    // General errors
    error ZeroAddress();
    error ZeroAmount();
    error ArrayLengthMismatch();
    error TransferFailed();
}