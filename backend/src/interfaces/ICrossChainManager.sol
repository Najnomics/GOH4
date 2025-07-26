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
        uint256 deadline;
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

    // View functions
    function getSwapState(bytes32 swapId) external view returns (SwapState memory);
    function isSwapActive(bytes32 swapId) external view returns (bool);
    function getUserActiveSwaps(address user) external view returns (bytes32[] memory);

    // Management functions
    function updateBridgeIntegration(address newBridgeIntegration) external;
    function updateChainConfiguration(uint256 chainId, bool enabled, uint256 maxGasPrice) external;
    function pauseCrossChainOperations(bool pauseState) external;
    function pause() external;
    function unpause() external;
    function getSwapStatistics() external view returns (
        uint256 totalSwapsCount,
        uint256 successfulSwapsCount,
        uint256 failedSwapsCount,
        uint256 averageExecutionTime
    );
}