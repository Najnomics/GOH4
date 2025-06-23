// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Interface for Cross Chain Manager
interface ICrossChainManager {
    struct CrossChainSwapParams {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 sourceChainId;
        uint256 destinationChainId;
        uint256 deadline;
        bytes swapData;
    }

    struct SwapState {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 sourceChainId;
        uint256 destinationChainId;
        uint256 initiatedAt;
        uint256 completedAt;
        SwapStatus status;
        bytes32 bridgeTransactionId;
    }

    enum SwapStatus {
        Initiated,
        Bridging,
        Swapping,
        BridgingBack,
        Completed,
        Failed,
        Recovered
    }

    // Core cross-chain functions
    function initiateCrossChainSwap(CrossChainSwapParams calldata params) external returns (bytes32 swapId);
    function handleDestinationSwap(bytes32 swapId, bytes calldata swapData) external;
    function completeCrossChainSwap(bytes32 swapId) external;

    // Recovery functions
    function emergencyRecovery(bytes32 swapId) external;
    function claimFailedSwap(bytes32 swapId) external;

    // Status functions
    function getSwapState(bytes32 swapId) external view returns (SwapState memory);
    function isSwapActive(bytes32 swapId) external view returns (bool);
    function getUserActiveSwaps(address user) external view returns (bytes32[] memory);

    // Configuration functions
    function updateBridgeIntegration(address newBridgeIntegration) external;
    function updateChainConfiguration(uint256 chainId, bool enabled, uint256 maxGasPrice) external;
    function pauseCrossChainOperations(bool pause) external;

    // Analytics functions
    function getSwapStatistics() external view returns (
        uint256 totalSwaps,
        uint256 successfulSwaps,
        uint256 failedSwaps,
        uint256 averageExecutionTime
    );
}