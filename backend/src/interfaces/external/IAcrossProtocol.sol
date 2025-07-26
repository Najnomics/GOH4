// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SpokePoolInterface} from "@across-protocol/contracts/interfaces/SpokePoolInterface.sol";

/// @title Across Protocol Interface for Gas Optimization Hook
interface IAcrossProtocol {
    // Re-export core SpokePool structs for our hook
    struct BridgeParams {
        address depositor;
        address recipient;
        address originToken;
        uint256 amount;
        uint256 destinationChainId;
        int64 relayerFeePct;
        uint32 quoteTimestamp;
        bytes message;
        uint256 maxCount;
    }

    struct BridgeStatus {
        bool isCompleted;
        bool isFailed;
        uint256 fillAmount;
        uint256 totalRelayerFeePct;
        uint32 depositId;
        bytes32 transactionHash;
    }

    // Enhanced functions for gas optimization
    function getBridgeFeeQuote(
        address originToken,
        uint256 amount,
        uint256 destinationChainId
    ) external view returns (uint256 bridgeFeeUSD, uint256 estimatedTime);

    function getSpokePool(uint256 chainId) external view returns (address spokePool);
    
    function isChainSupported(uint256 chainId) external view returns (bool);
    
    function getMinDepositAmount(address token, uint256 chainId) external view returns (uint256);
    
    function getMaxDepositAmount(address token, uint256 chainId) external view returns (uint256);

    function depositFor(BridgeParams calldata params) external payable returns (bytes32 depositHash);

    function getDepositStatus(bytes32 depositHash) external view returns (BridgeStatus memory);

    // Events
    event BridgeInitiated(
        bytes32 indexed depositHash,
        address indexed depositor,
        address indexed recipient,
        address originToken,
        uint256 amount,
        uint256 destinationChainId
    );

    event BridgeCompleted(
        bytes32 indexed depositHash,
        uint256 fillAmount,
        uint256 totalRelayerFeePct
    );

    event BridgeFailed(
        bytes32 indexed depositHash,
        string reason
    );

    // Errors
    error UnsupportedChain(uint256 chainId);
    error InvalidBridgeAmount(uint256 amount);
    error BridgeNotFound(bytes32 depositHash);
    error InsufficientBridgeFee();
}