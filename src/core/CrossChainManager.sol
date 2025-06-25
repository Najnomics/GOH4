// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICrossChainManager} from "../interfaces/ICrossChainManager.sol";
import {IAcrossProtocol} from "../interfaces/external/IAcrossProtocol.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";
import {ChainUtils} from "../libraries/ChainUtils.sol";

/// @title Cross Chain Manager for coordinating cross-chain swaps
contract CrossChainManager is ICrossChainManager, Ownable, ReentrancyGuard {
    using ChainUtils for uint256;

    // State storage
    mapping(bytes32 => SwapState) private swapStates;
    mapping(address => bytes32[]) private userActiveSwaps;
    mapping(uint256 => bool) public supportedChains;
    
    IAcrossProtocol public acrossIntegration;
    bool public isPaused;
    
    // Statistics
    uint256 public totalSwaps;
    uint256 public successfulSwaps;
    uint256 public failedSwaps;
    uint256 private totalExecutionTime;

    modifier whenNotPaused() {
        if (isPaused) revert Errors.EmergencyPauseActive();
        _;
    }

    modifier validChain(uint256 chainId) {
        if (!supportedChains[chainId]) revert Errors.InvalidDestinationChain();
        _;
    }

    constructor(address initialOwner, address _acrossIntegration) Ownable(initialOwner) {
        acrossIntegration = IAcrossProtocol(_acrossIntegration);
        _initializeSupportedChains();
    }

    /// @inheritdoc ICrossChainManager
    function initiateCrossChainSwap(CrossChainSwapParams calldata params) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        validChain(params.destinationChainId)
        returns (bytes32 swapId) 
    {
        if (params.user == address(0)) revert Errors.ZeroAddress();
        if (params.amountIn == 0) revert Errors.ZeroAmount();
        if (params.deadline < block.timestamp) revert Errors.InvalidBridgeParams();
        
        swapId = keccak256(abi.encodePacked(
            params.user,
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            params.destinationChainId,
            block.timestamp,
            totalSwaps
        ));

        SwapState storage swap = swapStates[swapId];
        swap.user = params.user;
        swap.tokenIn = params.tokenIn;
        swap.tokenOut = params.tokenOut;
        swap.amountIn = params.amountIn;
        swap.sourceChainId = params.sourceChainId;
        swap.destinationChainId = params.destinationChainId;
        swap.initiatedAt = block.timestamp;
        swap.status = SwapStatus.Initiated;

        userActiveSwaps[params.user].push(swapId);
        totalSwaps++;

        emit Events.CrossChainSwapInitiated(
            swapId,
            params.user,
            params.sourceChainId,
            params.destinationChainId,
            params.tokenIn,
            params.tokenOut,
            params.amountIn
        );

        return swapId;
    }

    /// @inheritdoc ICrossChainManager
    function handleDestinationSwap(bytes32 swapId, bytes calldata swapData) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        SwapState storage swap = swapStates[swapId];
        if (swap.user == address(0)) revert Errors.CrossChainSwapFailed();
        if (swap.status != SwapStatus.Bridging) revert Errors.CrossChainSwapFailed();

        swap.status = SwapStatus.Swapping;
        
        // Here would be the actual swap execution logic
        // For now, we'll simulate successful swap
        swap.amountOut = _simulateSwapExecution(swap.amountIn);
        swap.status = SwapStatus.BridgingBack;
    }

    /// @inheritdoc ICrossChainManager
    function completeCrossChainSwap(bytes32 swapId) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        SwapState storage swap = swapStates[swapId];
        if (swap.user == address(0)) revert Errors.CrossChainSwapFailed();
        if (swap.status != SwapStatus.BridgingBack) revert Errors.CrossChainSwapFailed();

        swap.status = SwapStatus.Completed;
        swap.completedAt = block.timestamp;
        
        successfulSwaps++;
        totalExecutionTime += (swap.completedAt - swap.initiatedAt);
        
        _removeUserActiveSwap(swap.user, swapId);

        emit Events.CrossChainSwapCompleted(
            swapId,
            swap.user,
            swap.amountOut,
            _calculateSavings(swap.amountIn, swap.amountOut)
        );
    }

    /// @inheritdoc ICrossChainManager
    function emergencyRecovery(bytes32 swapId) external override nonReentrant {
        SwapState storage swap = swapStates[swapId];
        if (swap.user != msg.sender && msg.sender != owner()) {
            revert Errors.UnauthorizedSender();
        }
        
        if (swap.status == SwapStatus.Completed || swap.status == SwapStatus.Recovered) {
            revert Errors.CrossChainSwapFailed();
        }

        // Check if swap has timed out (more than 1 hour)
        if (block.timestamp - swap.initiatedAt < 3600) {
            revert Errors.BridgeTimeout();
        }

        swap.status = SwapStatus.Recovered;
        failedSwaps++;
        
        _removeUserActiveSwap(swap.user, swapId);
    }

    /// @inheritdoc ICrossChainManager
    function claimFailedSwap(bytes32 swapId) external override nonReentrant {
        SwapState storage swap = swapStates[swapId];
        if (swap.user != msg.sender) revert Errors.UnauthorizedSender();
        if (swap.status != SwapStatus.Failed) revert Errors.CrossChainSwapFailed();

        swap.status = SwapStatus.Recovered;
        _removeUserActiveSwap(swap.user, swapId);
    }

    /// @inheritdoc ICrossChainManager
    function getSwapState(bytes32 swapId) external view override returns (SwapState memory) {
        return swapStates[swapId];
    }

    /// @inheritdoc ICrossChainManager
    function isSwapActive(bytes32 swapId) external view override returns (bool) {
        SwapStatus status = swapStates[swapId].status;
        return status != SwapStatus.Completed && 
               status != SwapStatus.Failed && 
               status != SwapStatus.Recovered;
    }

    /// @inheritdoc ICrossChainManager
    function getUserActiveSwaps(address user) external view override returns (bytes32[] memory) {
        return userActiveSwaps[user];
    }

    /// @inheritdoc ICrossChainManager
    function updateBridgeIntegration(address newBridgeIntegration) external override onlyOwner {
        if (newBridgeIntegration == address(0)) revert Errors.ZeroAddress();
        acrossIntegration = IAcrossProtocol(newBridgeIntegration);
    }

    /// @inheritdoc ICrossChainManager
    function updateChainConfiguration(uint256 chainId, bool enabled, uint256 maxGasPrice) external override onlyOwner {
        chainId.validateChainId();
        supportedChains[chainId] = enabled;
        emit Events.ChainConfigUpdated(chainId, enabled, maxGasPrice);
    }

    /// @inheritdoc ICrossChainManager
    function pauseCrossChainOperations(bool pause) external override onlyOwner {
        isPaused = pause;
        emit Events.EmergencyPauseToggled(pause, msg.sender);
    }

    /// @inheritdoc ICrossChainManager
    function getSwapStatistics() external view override returns (
        uint256 totalSwapsCount,
        uint256 successfulSwapsCount,
        uint256 failedSwapsCount,
        uint256 averageExecutionTime
    ) {
        totalSwapsCount = totalSwaps;
        successfulSwapsCount = successfulSwaps;
        failedSwapsCount = failedSwaps;
        
        if (successfulSwaps > 0) {
            averageExecutionTime = totalExecutionTime / successfulSwaps;
        } else {
            averageExecutionTime = 0;
        }
    }

    function _initializeSupportedChains() private {
        supportedChains[Constants.ETHEREUM_CHAIN_ID] = true;
        supportedChains[Constants.ARBITRUM_CHAIN_ID] = true;
        supportedChains[Constants.OPTIMISM_CHAIN_ID] = true;
        supportedChains[Constants.POLYGON_CHAIN_ID] = true;
        supportedChains[Constants.BASE_CHAIN_ID] = true;
    }

    function _simulateSwapExecution(uint256 amountIn) private pure returns (uint256) {
        // Simulate 0.3% fee (typical Uniswap fee)
        return amountIn - (amountIn * 30) / 10000;
    }

    function _calculateSavings(uint256 amountIn, uint256 amountOut) private pure returns (uint256) {
        // Simplified savings calculation for demonstration
        return amountIn > amountOut ? amountIn - amountOut : 0;
    }

    function _removeUserActiveSwap(address user, bytes32 swapId) private {
        bytes32[] storage userSwaps = userActiveSwaps[user];
        for (uint256 i = 0; i < userSwaps.length; i++) {
            if (userSwaps[i] == swapId) {
                userSwaps[i] = userSwaps[userSwaps.length - 1];
                userSwaps.pop();
                break;
            }
        }
    }
}