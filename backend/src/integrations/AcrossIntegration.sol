// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SpokePoolInterface} from "@across-protocol/contracts/interfaces/SpokePoolInterface.sol";
import {V3SpokePoolInterface} from "@across-protocol/contracts/interfaces/V3SpokePoolInterface.sol";
import {IAcrossProtocol} from "../interfaces/external/IAcrossProtocol.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";

/// @title Enhanced Across Protocol Integration for Cross-Chain Gas Optimization
/// @notice Integrates with Across Protocol V3 for fast, secure cross-chain bridging
contract AcrossIntegration is IAcrossProtocol, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Across Protocol V3 spoke pool interface
    V3SpokePoolInterface public immutable hubPool;
    
    // Bridge pause state
    bool public bridgePaused = false;
    
    // Mapping from chainId to SpokePool address
    mapping(uint256 => address) public spokePools;
    
    // Mapping from depositHash to BridgeStatus
    mapping(bytes32 => BridgeStatus) public bridgeStatuses;
    
    // Mapping from token to chain to min/max amounts
    mapping(address => mapping(uint256 => uint256)) public minDepositAmounts;
    mapping(address => mapping(uint256 => uint256)) public maxDepositAmounts;
    
    // Supported chains and route configurations
    mapping(uint256 => bool) public supportedChains;
    mapping(uint256 => uint256) public chainBridgeTimes; // Chain ID to estimated bridge time
    
    // Bridge fee configuration
    struct BridgeFeeConfig {
        uint256 baseFeeUSD;           // Base fee in USD (18 decimals)
        uint256 percentageBPS;        // Percentage fee in basis points
        uint256 minRelayerFeePct;     // Minimum relayer fee percentage (18 decimals)
        uint256 maxRelayerFeePct;     // Maximum relayer fee percentage (18 decimals)
    }
    
    // Internal struct to avoid stack too deep errors
    struct V3DepositParams {
        address depositor;
        address recipient;
        address originToken;
        address destinationToken;
        uint256 amount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 quoteTimestamp;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        bytes message;
    }
    
    BridgeFeeConfig public bridgeFeeConfig;
    
    // Relayer monitoring and optimization
    mapping(address => uint256) public relayerPerformance; // Relayer success rate (basis points)
    address[] public trustedRelayers;
    
    // Deposit tracking with enhanced metadata
    uint32 public nextDepositId = 1;
    mapping(bytes32 => uint32) public depositHashToId;
    mapping(bytes32 => address) public depositHashToRelayer;
    
    // Events for enhanced monitoring
    event SpokePoolUpdated(uint256 indexed chainId, address indexed oldPool, address indexed newPool);
    event RelayerOptimized(bytes32 indexed depositHash, address indexed relayer, uint256 expectedTime);
    event BridgeTimeUpdated(uint256 indexed chainId, uint256 oldTime, uint256 newTime);
    event BridgeFeeConfigUpdated(uint256 baseFeeUSD, uint256 percentageBPS);

    constructor(
        address initialOwner,
        address _hubPool
    ) Ownable(initialOwner) {
        hubPool = V3SpokePoolInterface(_hubPool);
        
        // Initialize default bridge fee configuration
        bridgeFeeConfig = BridgeFeeConfig({
            baseFeeUSD: 2 * 1e18,          // $2 USD base fee
            percentageBPS: 5,              // 0.05% percentage fee
            minRelayerFeePct: 1e16,        // 1% minimum relayer fee
            maxRelayerFeePct: 5e17         // 50% maximum relayer fee
        });
        
        _initializeSupportedChains();
    }

    /// @inheritdoc IAcrossProtocol
    function getBridgeFeeQuote(
        address /* originToken */,
        uint256 amount,
        uint256 destinationChainId
    ) external view override returns (uint256 bridgeFeeUSD, uint256 estimatedTime) {
        if (!supportedChains[destinationChainId]) {
            revert UnsupportedChain(destinationChainId);
        }

        // Calculate percentage-based fee
        uint256 percentageFee = (amount * bridgeFeeConfig.percentageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
        
        // Add base fee
        bridgeFeeUSD = bridgeFeeConfig.baseFeeUSD + percentageFee;
        
        // Get estimated bridge time for destination chain
        estimatedTime = chainBridgeTimes[destinationChainId];
        if (estimatedTime == 0) {
            estimatedTime = 900; // Default 15 minutes
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

    /// @notice Get optimal relayer for a bridge transaction
    function getOptimalRelayer(
        address token,
        uint256 amount,
        uint256 destinationChainId
    ) external view returns (address optimalRelayer, uint256 estimatedFee) {
        // Find the most performant relayer for this route
        address bestRelayer = address(0);
        uint256 bestPerformance = 0;
        
        for (uint256 i = 0; i < trustedRelayers.length; i++) {
            address relayer = trustedRelayers[i];
            uint256 performance = relayerPerformance[relayer];
            
            if (performance > bestPerformance) {
                bestPerformance = performance;
                bestRelayer = relayer;
            }
        }
        
        // Fallback to a default relayer if no trusted relayers are available
        if (bestRelayer == address(0)) {
            bestRelayer = address(0x1); // Default fallback relayer
        }
        
        optimalRelayer = bestRelayer;
        
        // Calculate estimated fee for optimal relayer
        estimatedFee = _calculateOptimalRelayerFee(token, amount, destinationChainId, optimalRelayer);
    }

    /// @inheritdoc IAcrossProtocol
    function depositFor(BridgeParams calldata params) 
        external 
        payable 
        override 
        nonReentrant 
        returns (bytes32 depositHash) 
    {
        _validateDepositParams(params);
        
        // Generate deposit hash and setup state
        depositHash = _setupDeposit(params);
        
        // Execute the bridge transaction
        _executeBridgeDeposit(params, depositHash);

        return depositHash;
    }

    function _validateDepositParams(BridgeParams calldata params) internal view {
        if (bridgePaused) {
            revert("Bridge operations are paused");
        }

        if (!supportedChains[params.destinationChainId]) {
            revert UnsupportedChain(params.destinationChainId);
        }

        if (params.amount == 0) {
            revert InvalidBridgeAmount(params.amount);
        }

        if (spokePools[block.chainid] == address(0)) {
            revert UnsupportedChain(block.chainid);
        }

        // Validate deposit amount limits
        _validateDepositLimits(params.originToken, params.amount, params.destinationChainId);
    }

    function _setupDeposit(BridgeParams calldata params) internal returns (bytes32 depositHash) {
        // Validate and optimize relayer fee
        int64 optimizedRelayerFee = _optimizeRelayerFee(params.relayerFeePct, params.originToken, params.amount);

        // Generate unique deposit hash
        depositHash = _generateDepositHash(params, nextDepositId);

        // Handle token transfer and approval
        _handleTokenTransfer(params, spokePools[block.chainid]);

        // Store deposit info with enhanced metadata
        bridgeStatuses[depositHash] = BridgeStatus({
            isCompleted: false,
            isFailed: false,
            fillAmount: 0,
            totalRelayerFeePct: optimizedRelayerFee >= 0 ? uint256(int256(optimizedRelayerFee)) : 0,
            depositId: nextDepositId,
            transactionHash: bytes32(0)
        });

        depositHashToId[depositHash] = nextDepositId;
        
        // Find optimal relayer
        (address optimalRelayer,) = this.getOptimalRelayer(
            params.originToken, 
            params.amount, 
            params.destinationChainId
        );
        depositHashToRelayer[depositHash] = optimalRelayer;

        nextDepositId++;
    }

    function _executeBridgeDeposit(BridgeParams calldata params, bytes32 depositHash) internal {
        address spokePool = spokePools[block.chainid];
        address optimalRelayer = depositHashToRelayer[depositHash];

        // Pack parameters to avoid stack too deep
        V3DepositParams memory depositParams = V3DepositParams({
            depositor: params.depositor,
            recipient: params.recipient,
            originToken: params.originToken,
            destinationToken: address(0),
            amount: params.amount,
            outputAmount: 0,
            destinationChainId: params.destinationChainId,
            exclusiveRelayer: address(0),
            quoteTimestamp: params.quoteTimestamp,
            fillDeadline: uint32(block.timestamp + 3600),
            exclusivityDeadline: 0,
            message: params.message
        });

        // Execute deposit through Across V3 SpokePool
        try V3SpokePoolInterface(spokePool).depositV3{value: msg.value}(
            depositParams.depositor,
            depositParams.recipient,
            depositParams.originToken,
            depositParams.destinationToken,
            depositParams.amount,
            depositParams.outputAmount,
            depositParams.destinationChainId,
            depositParams.exclusiveRelayer,
            depositParams.quoteTimestamp,
            depositParams.fillDeadline,
            depositParams.exclusivityDeadline,
            depositParams.message
        ) {
            emit BridgeInitiated(
                depositHash,
                params.depositor,
                params.recipient,
                params.originToken,
                params.amount,
                params.destinationChainId
            );
            
            emit RelayerOptimized(depositHash, optimalRelayer, chainBridgeTimes[params.destinationChainId]);
            
        } catch Error(string memory reason) {
            // Mark as failed and refund
            bridgeStatuses[depositHash].isFailed = true;
            _refundDeposit(params.depositor, params.originToken, params.amount);
            emit BridgeFailed(depositHash, reason);
            revert(reason);
        } catch (bytes memory /* lowLevelData */) {
            // Handle low-level failures
            bridgeStatuses[depositHash].isFailed = true;
            _refundDeposit(params.depositor, params.originToken, params.amount);
            emit BridgeFailed(depositHash, "Low-level call failed");
            revert("Bridge execution failed");
        }
    }

    /// @inheritdoc IAcrossProtocol
    function getDepositStatus(bytes32 depositHash) external view override returns (BridgeStatus memory) {
        if (depositHashToId[depositHash] == 0) {
            // Return default status for non-existent deposits instead of reverting
            return BridgeStatus({
                isCompleted: false,
                isFailed: false,
                fillAmount: 0,
                totalRelayerFeePct: 0,
                depositId: 0,
                transactionHash: bytes32(0)
            });
        }
        return bridgeStatuses[depositHash];
    }

    /// @notice Get detailed bridge analytics
    function getBridgeAnalytics(bytes32 depositHash) external view returns (
        uint256 bridgeTime,
        address relayer,
        uint256 actualFee,
        bool isOptimal
    ) {
        BridgeStatus memory status = bridgeStatuses[depositHash];
        if (depositHashToId[depositHash] == 0) {
            revert BridgeNotFound(depositHash);
        }
        
        relayer = depositHashToRelayer[depositHash];
        actualFee = status.totalRelayerFeePct;
        
        // Calculate if this was an optimal execution
        uint256 relayerScore = relayerPerformance[relayer];
        isOptimal = relayerScore > 8000; // 80% success rate threshold
        
        // Bridge time would be calculated from actual timestamps
        bridgeTime = 0; // Placeholder - would track actual execution time
    }

    // Admin functions
    function updateSpokePool(uint256 chainId, address spokePool) external onlyOwner {
        address oldPool = spokePools[chainId];
        spokePools[chainId] = spokePool;
        supportedChains[chainId] = spokePool != address(0);
        
        emit SpokePoolUpdated(chainId, oldPool, spokePool);
    }

    function updateBridgeTime(uint256 chainId, uint256 estimatedTime) external onlyOwner {
        uint256 oldTime = chainBridgeTimes[chainId];
        chainBridgeTimes[chainId] = estimatedTime;
        
        emit BridgeTimeUpdated(chainId, oldTime, estimatedTime);
    }

    function updateBridgeTime(uint256 newMaxTime) external onlyOwner {
        // Update bridge time for current chain
        uint256 oldTime = chainBridgeTimes[block.chainid];
        chainBridgeTimes[block.chainid] = newMaxTime;
        
        emit BridgeTimeUpdated(block.chainid, oldTime, newMaxTime);
    }

    function updateDepositLimits(
        address token,
        uint256 chainId,
        uint256 minAmount,
        uint256 maxAmount
    ) external onlyOwner {
        _updateDepositLimitsInternal(token, chainId, minAmount, maxAmount);
    }

    function updateDepositLimits(
        address token,
        uint256 minAmount,
        uint256 maxAmount
    ) external onlyOwner {
        // Update for all supported chains
        uint256[5] memory chainIds = [
            Constants.ETHEREUM_CHAIN_ID,
            Constants.ARBITRUM_CHAIN_ID, 
            Constants.OPTIMISM_CHAIN_ID,
            Constants.POLYGON_CHAIN_ID,
            Constants.BASE_CHAIN_ID
        ];
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (supportedChains[chainIds[i]]) {
                _updateDepositLimitsInternal(token, chainIds[i], minAmount, maxAmount);
            }
        }
    }

    function _updateDepositLimitsInternal(
        address token,
        uint256 chainId,
        uint256 minAmount,
        uint256 maxAmount
    ) internal {
        if (maxAmount > 0 && minAmount > maxAmount) {
            revert InvalidBridgeAmount(minAmount);
        }
        
        minDepositAmounts[token][chainId] = minAmount;
        maxDepositAmounts[token][chainId] = maxAmount;
    }

    function updateBridgeFeeConfig(
        uint256 newBaseFeeUSD,
        uint256 newPercentageBPS
    ) external onlyOwner {
        if (newPercentageBPS > 1000) { // Max 10%
            revert InvalidBridgeAmount(newPercentageBPS);
        }
        
        bridgeFeeConfig.baseFeeUSD = newBaseFeeUSD;
        bridgeFeeConfig.percentageBPS = newPercentageBPS;
        
        emit BridgeFeeConfigUpdated(newBaseFeeUSD, newPercentageBPS);
    }

    function addTrustedRelayer(address relayer, uint256 performanceScore) external onlyOwner {
        if (performanceScore > Constants.BASIS_POINTS_DENOMINATOR) {
            revert InvalidBridgeAmount(performanceScore);
        }
        
        trustedRelayers.push(relayer);
        relayerPerformance[relayer] = performanceScore;
    }

    function updateRelayerPerformance(address relayer, uint256 newScore) external onlyOwner {
        if (newScore > Constants.BASIS_POINTS_DENOMINATOR) {
            revert InvalidBridgeAmount(newScore);
        }
        
        relayerPerformance[relayer] = newScore;
    }

    function removeTrustedRelayer(address relayer) external onlyOwner {
        // Remove relayer from trusted list
        for (uint256 i = 0; i < trustedRelayers.length; i++) {
            if (trustedRelayers[i] == relayer) {
                trustedRelayers[i] = trustedRelayers[trustedRelayers.length - 1];
                trustedRelayers.pop();
                break;
            }
        }
        
        // Reset performance score
        relayerPerformance[relayer] = 0;
    }

    function pauseBridge(bool paused) external onlyOwner {
        bridgePaused = paused;
    }

    function updateChainConfiguration(uint256 chainId, address newSpokePool, bool isSupported) external onlyOwner {
        address oldPool = spokePools[chainId];
        spokePools[chainId] = newSpokePool;
        supportedChains[chainId] = isSupported;
        
        emit SpokePoolUpdated(chainId, oldPool, newSpokePool);
    }

    function getMinMaxDepositAmounts(address token) external view returns (uint256 minAmount, uint256 maxAmount) {
        // Return aggregate min/max across all chains for this token
        minAmount = type(uint256).max;
        maxAmount = 0;
        
        uint256[5] memory chainIds = [
            Constants.ETHEREUM_CHAIN_ID,
            Constants.ARBITRUM_CHAIN_ID, 
            Constants.OPTIMISM_CHAIN_ID,
            Constants.POLYGON_CHAIN_ID,
            Constants.BASE_CHAIN_ID
        ];
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            if (supportedChains[chainId]) {
                uint256 chainMin = minDepositAmounts[token][chainId];
                uint256 chainMax = maxDepositAmounts[token][chainId];
                
                if (chainMin > 0 && chainMin < minAmount) {
                    minAmount = chainMin;
                }
                if (chainMax > maxAmount) {
                    maxAmount = chainMax;
                }
            }
        }
        
        if (minAmount == type(uint256).max) {
            minAmount = 0;
        }
    }

    function calculateBridgeCost(address token, uint256 amount, uint256 destinationChain) external view returns (uint256 cost) {
        (cost,) = this.getBridgeFeeQuote(token, amount, destinationChain);
    }

    function getSupportedChains() external view returns (uint256[] memory chains) {
        uint256[5] memory allChainIds = [
            Constants.ETHEREUM_CHAIN_ID,
            Constants.ARBITRUM_CHAIN_ID, 
            Constants.OPTIMISM_CHAIN_ID,
            Constants.POLYGON_CHAIN_ID,
            Constants.BASE_CHAIN_ID
        ];
        
        uint256 supportedCount = 0;
        for (uint256 i = 0; i < allChainIds.length; i++) {
            if (supportedChains[allChainIds[i]]) {
                supportedCount++;
            }
        }
        
        chains = new uint256[](supportedCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allChainIds.length; i++) {
            if (supportedChains[allChainIds[i]]) {
                chains[index] = allChainIds[i];
                index++;
            }
        }
    }

    // Bridge status updates (would be called by monitoring system)
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
            
            // Update relayer performance based on successful completion
            address relayer = depositHashToRelayer[depositHash];
            if (relayer != address(0)) {
                _updateRelayerSuccess(relayer);
            }
        }
    }

    // Internal functions
    function _validateDepositLimits(address token, uint256 amount, uint256 destinationChain) private view {
        uint256 minAmount = minDepositAmounts[token][destinationChain];
        uint256 maxAmount = maxDepositAmounts[token][destinationChain];
        
        if (amount < minAmount || (maxAmount > 0 && amount > maxAmount)) {
            revert InvalidBridgeAmount(amount);
        }
    }

    function _optimizeRelayerFee(int64 proposedFee, address /* token */, uint256 /* amount */) private view returns (int64) {
        uint256 absFee = proposedFee >= 0 ? uint256(int256(proposedFee)) : 0;
        
        // Ensure fee is within acceptable bounds
        if (absFee < bridgeFeeConfig.minRelayerFeePct) {
            return int64(int256(bridgeFeeConfig.minRelayerFeePct));
        }
        
        if (absFee > bridgeFeeConfig.maxRelayerFeePct) {
            return int64(int256(bridgeFeeConfig.maxRelayerFeePct));
        }
        
        return proposedFee;
    }

    function _generateDepositHash(BridgeParams calldata params, uint32 depositId) private view returns (bytes32) {
        return keccak256(abi.encodePacked(
            params.depositor,
            params.recipient,
            params.originToken,
            params.amount,
            params.destinationChainId,
            block.timestamp,
            depositId,
            block.chainid
        ));
    }

    function _handleTokenTransfer(BridgeParams calldata params, address spokePool) private {
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
            
            // Approve SpokePool
            IERC20(params.originToken).forceApprove(spokePool, params.amount);
        }
    }

    function _calculateOptimalRelayerFee(
        address /* token */,
        uint256 amount,
        uint256 /* destinationChain */,
        address relayer
    ) private view returns (uint256) {
        // Calculate base fee as percentage of transfer amount
        uint256 baseFee = (amount * bridgeFeeConfig.percentageBPS) / Constants.BASIS_POINTS_DENOMINATOR;
        
        // Adjust based on relayer performance
        uint256 relayerScore = relayerPerformance[relayer];
        if (relayerScore > 9000) { // 90%+ success rate
            baseFee = (baseFee * 95) / 100; // 5% discount
        } else if (relayerScore < 7000) { // <70% success rate  
            baseFee = (baseFee * 110) / 100; // 10% premium
        }
        
        return baseFee;
    }

    function _updateRelayerSuccess(address relayer) private {
        uint256 currentScore = relayerPerformance[relayer];
        // Increment success rate (simplified - would use more sophisticated tracking)
        if (currentScore < Constants.BASIS_POINTS_DENOMINATOR) {
            relayerPerformance[relayer] = currentScore + 10; // Incremental improvement
        }
    }

    function _initializeSupportedChains() private {
        // Initialize with real Across V3 SpokePool addresses
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

        // Set bridge times based on actual Across performance
        chainBridgeTimes[Constants.ETHEREUM_CHAIN_ID] = 300;   // 5 minutes
        chainBridgeTimes[Constants.ARBITRUM_CHAIN_ID] = 180;   // 3 minutes
        chainBridgeTimes[Constants.OPTIMISM_CHAIN_ID] = 180;   // 3 minutes
        chainBridgeTimes[Constants.POLYGON_CHAIN_ID] = 600;    // 10 minutes
        chainBridgeTimes[Constants.BASE_CHAIN_ID] = 180;       // 3 minutes

        // Set default deposit limits
        _setDefaultDepositLimits();
    }

    function _setDefaultDepositLimits() private {
        // ETH limits (in wei) based on Across Protocol limits
        address eth = address(0);
        
        // Set conservative limits for each chain
        uint256[5] memory chainIds = [
            Constants.ETHEREUM_CHAIN_ID,
            Constants.ARBITRUM_CHAIN_ID, 
            Constants.OPTIMISM_CHAIN_ID,
            Constants.POLYGON_CHAIN_ID,
            Constants.BASE_CHAIN_ID
        ];
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            minDepositAmounts[eth][chainId] = 0.001 ether;
            
            if (chainId == Constants.POLYGON_CHAIN_ID) {
                maxDepositAmounts[eth][chainId] = 50 ether;  // Lower limit for Polygon
            } else {
                maxDepositAmounts[eth][chainId] = 100 ether; // Standard limit
            }
        }
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

    function emergencyPause() external onlyOwner {
        // Emergency pause functionality would be implemented here
        // This could disable new deposits while allowing existing ones to complete
    }

    receive() external payable {}
}