// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SpokePoolInterface} from "@across-protocol/contracts/interfaces/SpokePoolInterface.sol";
import {IAcrossProtocol} from "../interfaces/external/IAcrossProtocol.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";

/// @title Across Protocol Integration for Cross-Chain Gas Optimization
contract AcrossIntegration is IAcrossProtocol, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Mapping from chainId to SpokePool address
    mapping(uint256 => address) public spokePools;
    
    // Mapping from depositHash to BridgeStatus
    mapping(bytes32 => BridgeStatus) public bridgeStatuses;
    
    // Mapping from token to chain to min/max amounts
    mapping(address => mapping(uint256 => uint256)) public minDepositAmounts;
    mapping(address => mapping(uint256 => uint256)) public maxDepositAmounts;
    
    // Supported chains
    mapping(uint256 => bool) public supportedChains;
    
    // Bridge fee parameters
    uint256 public baseBridgeFeeUSD = 2 * 1e18; // $2 base fee
    uint256 public bridgeFeePercentageBPS = 5; // 0.05% fee
    
    // Deposit tracking
    uint32 public nextDepositId = 1;
    mapping(bytes32 => uint32) public depositHashToId;

    constructor(address initialOwner) Ownable(initialOwner) {
        _initializeSupportedChains();
    }

    /// @inheritdoc IAcrossProtocol
    function getBridgeFeeQuote(
        address originToken,
        uint256 amount,
        uint256 destinationChainId
    ) external view override returns (uint256 bridgeFeeUSD, uint256 estimatedTime) {
        if (!supportedChains[destinationChainId]) {
            revert UnsupportedChain(destinationChainId);
        }

        // Calculate percentage-based fee
        uint256 percentageFee = (amount * bridgeFeePercentageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
        
        // Add base fee (convert to token amount based on USD value)
        bridgeFeeUSD = baseBridgeFeeUSD + percentageFee;
        
        // Estimate bridge time based on destination chain
        if (destinationChainId == Constants.ARBITRUM_CHAIN_ID || 
            destinationChainId == Constants.OPTIMISM_CHAIN_ID ||
            destinationChainId == Constants.BASE_CHAIN_ID) {
            estimatedTime = 180; // 3 minutes for L2s
        } else if (destinationChainId == Constants.POLYGON_CHAIN_ID) {
            estimatedTime = 600; // 10 minutes for Polygon
        } else {
            estimatedTime = 900; // 15 minutes for other chains
        }
    }

    /// @inheritdoc IAcrossProtocol
    function getSpokePool(uint256 chainId) external view override returns (address spokePool) {
        spokePool = spokePools[chainId];
        if (spokePool == address(0)) {
            revert UnsupportedChain(chainId);
        }
    }

    /// @inheritdoc IAcrossProtocol
    function isChainSupported(uint256 chainId) external view override returns (bool) {
        return supportedChains[chainId];
    }

    /// @inheritdoc IAcrossProtocol
    function getMinDepositAmount(address token, uint256 chainId) external view override returns (uint256) {
        return minDepositAmounts[token][chainId];
    }

    /// @inheritdoc IAcrossProtocol
    function getMaxDepositAmount(address token, uint256 chainId) external view override returns (uint256) {
        return maxDepositAmounts[token][chainId];
    }

    /// @inheritdoc IAcrossProtocol
    function depositFor(BridgeParams calldata params) 
        external 
        payable 
        override 
        nonReentrant 
        returns (bytes32 depositHash) 
    {
        if (!supportedChains[params.destinationChainId]) {
            revert UnsupportedChain(params.destinationChainId);
        }

        if (params.amount == 0) {
            revert InvalidBridgeAmount(params.amount);
        }

        address spokePool = spokePools[block.chainid];
        if (spokePool == address(0)) {
            revert UnsupportedChain(block.chainid);
        }

        // Validate deposit amount
        uint256 minAmount = minDepositAmounts[params.originToken][params.destinationChainId];
        uint256 maxAmount = maxDepositAmounts[params.originToken][params.destinationChainId];
        
        if (params.amount < minAmount || (maxAmount > 0 && params.amount > maxAmount)) {
            revert InvalidBridgeAmount(params.amount);
        }

        // Generate deposit hash
        depositHash = keccak256(abi.encodePacked(
            params.depositor,
            params.recipient,
            params.originToken,
            params.amount,
            params.destinationChainId,
            block.timestamp,
            nextDepositId
        ));

        // Handle token transfer
        if (params.originToken == address(0)) {
            // ETH deposit
            if (msg.value != params.amount) {
                revert InvalidBridgeAmount(params.amount);
            }
        } else {
            // ERC20 deposit
            IERC20(params.originToken).safeTransferFrom(
                params.depositor,
                address(this),
                params.amount
            );
            
            // Approve SpokePool using low-level call
            (bool success, ) = params.originToken.call(
                abi.encodeWithSignature("approve(address,uint256)", spokePool, params.amount)
            );
            if (!success) revert InsufficientBridgeFee();
        }

        // Store deposit info
        bridgeStatuses[depositHash] = BridgeStatus({
            isCompleted: false,
            isFailed: false,
            fillAmount: 0,
            totalRelayerFeePct: params.relayerFeePct >= 0 ? uint256(int256(params.relayerFeePct)) : 0,
            depositId: nextDepositId,
            transactionHash: bytes32(0)
        });

        depositHashToId[depositHash] = nextDepositId;
        nextDepositId++;

        // Call SpokePool deposit
        try SpokePoolInterface(spokePool).depositFor{value: msg.value}(
            params.depositor,
            params.recipient,
            params.originToken,
            params.amount,
            params.destinationChainId,
            params.relayerFeePct,
            params.quoteTimestamp,
            params.message,
            params.maxCount
        ) {
            emit BridgeInitiated(
                depositHash,
                params.depositor,
                params.recipient,
                params.originToken,
                params.amount,
                params.destinationChainId
            );
        } catch Error(string memory reason) {
            // Mark as failed and refund
            bridgeStatuses[depositHash].isFailed = true;
            _refundDeposit(params.depositor, params.originToken, params.amount);
            emit BridgeFailed(depositHash, reason);
            revert(reason);
        }

        return depositHash;
    }

    /// @inheritdoc IAcrossProtocol
    function getDepositStatus(bytes32 depositHash) external view override returns (BridgeStatus memory) {
        if (depositHashToId[depositHash] == 0) {
            revert BridgeNotFound(depositHash);
        }
        return bridgeStatuses[depositHash];
    }

    // Admin functions
    function updateSpokePool(uint256 chainId, address spokePool) external onlyOwner {
        spokePools[chainId] = spokePool;
        supportedChains[chainId] = spokePool != address(0);
    }

    function updateDepositLimits(
        address token,
        uint256 chainId,
        uint256 minAmount,
        uint256 maxAmount
    ) external onlyOwner {
        minDepositAmounts[token][chainId] = minAmount;
        maxDepositAmounts[token][chainId] = maxAmount;
    }

    function updateBridgeFeeParameters(
        uint256 newBaseFeeUSD,
        uint256 newPercentageBPS
    ) external onlyOwner {
        baseBridgeFeeUSD = newBaseFeeUSD;
        bridgeFeePercentageBPS = newPercentageBPS;
    }

    // Bridge status updates (would be called by relayers/monitors)
    function updateBridgeStatus(
        bytes32 depositHash,
        bool isCompleted,
        uint256 fillAmount,
        bytes32 transactionHash
    ) external onlyOwner {
        BridgeStatus storage status = bridgeStatuses[depositHash];
        status.isCompleted = isCompleted;
        status.fillAmount = fillAmount;
        status.transactionHash = transactionHash;

        if (isCompleted) {
            emit BridgeCompleted(depositHash, fillAmount, status.totalRelayerFeePct);
        }
    }

    function _initializeSupportedChains() private {
        // Initialize with common SpokePool addresses (these would be updated with real addresses)
        spokePools[Constants.ETHEREUM_CHAIN_ID] = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        spokePools[Constants.ARBITRUM_CHAIN_ID] = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
        spokePools[Constants.OPTIMISM_CHAIN_ID] = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
        spokePools[Constants.POLYGON_CHAIN_ID] = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
        spokePools[Constants.BASE_CHAIN_ID] = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

        supportedChains[Constants.ETHEREUM_CHAIN_ID] = true;
        supportedChains[Constants.ARBITRUM_CHAIN_ID] = true;
        supportedChains[Constants.OPTIMISM_CHAIN_ID] = true;
        supportedChains[Constants.POLYGON_CHAIN_ID] = true;
        supportedChains[Constants.BASE_CHAIN_ID] = true;

        // Set default deposit limits (would be configured properly)
        _setDefaultDepositLimits();
    }

    function _setDefaultDepositLimits() private {
        // ETH limits (in wei)
        address eth = address(0);
        minDepositAmounts[eth][Constants.ARBITRUM_CHAIN_ID] = 0.001 ether;
        maxDepositAmounts[eth][Constants.ARBITRUM_CHAIN_ID] = 100 ether;
        
        minDepositAmounts[eth][Constants.OPTIMISM_CHAIN_ID] = 0.001 ether;
        maxDepositAmounts[eth][Constants.OPTIMISM_CHAIN_ID] = 100 ether;
        
        minDepositAmounts[eth][Constants.POLYGON_CHAIN_ID] = 0.001 ether;
        maxDepositAmounts[eth][Constants.POLYGON_CHAIN_ID] = 50 ether;
        
        minDepositAmounts[eth][Constants.BASE_CHAIN_ID] = 0.001 ether;
        maxDepositAmounts[eth][Constants.BASE_CHAIN_ID] = 100 ether;
    }

    function _refundDeposit(address depositor, address token, uint256 amount) private {
        if (token == address(0)) {
            // Refund ETH
            (bool success,) = depositor.call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            // Refund ERC20
            IERC20(token).safeTransfer(depositor, amount);
        }
    }

    // Emergency functions
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    receive() external payable {}
}