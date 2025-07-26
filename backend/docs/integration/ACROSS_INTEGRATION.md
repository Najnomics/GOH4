# 🌉 Across Protocol Integration Guide

## Overview

The Gas Optimization Hook integrates with Across Protocol to provide fast, secure, and cost-effective cross-chain asset bridging. This integration enables automatic routing of swaps to optimal chains while maintaining user funds security.

## Integration Architecture

### Across Protocol Components

**Spoke Pools**: Chain-specific smart contracts that handle:
- Token deposits and withdrawals
- Relay request management
- Fee calculation and collection
- Liquidity provision coordination

**Hub Pool**: Ethereum mainnet contract that:
- Manages overall protocol state
- Handles dispute resolution
- Coordinates cross-chain settlements
- Maintains security parameters

**Relayers**: Off-chain agents that:
- Monitor spoke pools for relay requests
- Provide fast liquidity on destination chains
- Submit proofs for settlement
- Earn fees for service provision

## Implementation Details

### Bridge Integration Contract

```solidity
contract AcrossIntegration {
    struct BridgeParams {
        address token;
        uint256 amount;
        uint256 destinationChainId;
        address recipient;
        uint256 relayerFeePct;
        uint256 timestamp;
    }
    
    function initiateBridge(BridgeParams calldata params) 
        external 
        returns (bytes32 bridgeId);
        
    function getBridgeFee(
        address token,
        uint256 amount,
        uint256 destinationChain
    ) external view returns (uint256 fee);
}
```

### Fee Structure

**Across Protocol Fees**:
- **Base Fee**: Fixed USD amount per transaction (~$0.50-2.00)
- **Percentage Fee**: 0.04-0.25% of bridged amount
- **Gas Fees**: Destination chain gas costs
- **Relayer Premium**: Variable based on speed/liquidity

**Dynamic Fee Calculation**:
```solidity
function calculateBridgeFee(
    address token,
    uint256 amount,
    uint256 destinationChain
) public view returns (uint256 totalFee) {
    uint256 baseFee = costParameters.baseBridgeFeeUSD;
    uint256 percentageFee = (amount * costParameters.bridgeFeePercentageBPS) / 10000;
    uint256 gasFee = estimateDestinationGas(destinationChain);
    
    totalFee = baseFee + percentageFee + gasFee;
}
```

## Bridge Flow Implementation

### 1. Bridge Initiation

```solidity
function initiateCrossChainSwap(CrossChainSwapParams calldata params) 
    external 
    returns (bytes32 swapId) 
{
    // Validate parameters
    require(params.amountIn > 0, "Invalid amount");
    require(params.deadline > block.timestamp, "Expired deadline");
    
    // Calculate bridge parameters
    BridgeParams memory bridgeParams = BridgeParams({
        token: params.tokenIn,
        amount: params.amountIn,
        destinationChainId: params.destinationChainId,
        recipient: address(this), // Contract receives on destination
        relayerFeePct: calculateOptimalRelayerFee(params),
        timestamp: block.timestamp
    });
    
    // Initiate bridge through Across
    bytes32 bridgeId = acrossIntegration.initiateBridge(bridgeParams);
    
    // Store swap state
    swapStates[swapId] = SwapState({
        user: params.user,
        bridgeTransactionId: bridgeId,
        status: SwapStatus.Bridging,
        // ... other fields
    });
    
    return swapId;
}
```

### 2. Destination Chain Handling

```solidity
function handleDestinationSwap(bytes32 swapId, bytes calldata swapData) 
    external 
{
    SwapState storage swap = swapStates[swapId];
    require(swap.status == SwapStatus.Bridging, "Invalid state");
    
    // Verify bridge completion via Across events
    require(verifyBridgeCompletion(swap.bridgeTransactionId), "Bridge not complete");
    
    // Execute swap on destination chain
    swap.status = SwapStatus.Swapping;
    uint256 swapOutput = executeDestinationSwap(swap, swapData);
    
    // Initiate return bridge if needed
    if (swap.destinationChainId != swap.sourceChainId) {
        initiateReturnBridge(swapId, swapOutput);
        swap.status = SwapStatus.BridgingBack;
    } else {
        swap.status = SwapStatus.Completed;
        swap.amountOut = swapOutput;
    }
}
```

### 3. Bridge Monitoring

```solidity
contract BridgeMonitor {
    mapping(bytes32 => BridgeStatus) public bridgeStatuses;
    
    struct BridgeStatus {
        bool initiated;
        bool completed;
        bool failed;
        uint256 timestamp;
        uint256 completionTime;
    }
    
    function updateBridgeStatus(bytes32 bridgeId, BridgeStatus calldata status) 
        external 
        onlyRelayer 
    {
        bridgeStatuses[bridgeId] = status;
        emit BridgeStatusUpdated(bridgeId, status);
    }
}
```

## Error Handling & Recovery

### Timeout Management

```solidity
function handleBridgeTimeout(bytes32 swapId) external {
    SwapState storage swap = swapStates[swapId];
    require(block.timestamp - swap.initiatedAt > MAX_BRIDGE_TIME, "Not timed out");
    
    // Attempt automatic recovery
    if (canAutoRecover(swap)) {
        initiateAutoRecovery(swap);
    } else {
        // Mark for manual recovery
        swap.status = SwapStatus.Failed;
        emit BridgeTimeoutDetected(swapId);
    }
}
```

### Failed Bridge Recovery

```solidity
function emergencyRecovery(bytes32 swapId) external {
    SwapState storage swap = swapStates[swapId];
    require(swap.user == msg.sender || msg.sender == owner(), "Unauthorized");
    
    // Check if bridge actually failed
    BridgeStatus memory status = bridgeMonitor.getBridgeStatus(swap.bridgeTransactionId);
    require(status.failed || isTimedOut(swap), "Recovery not available");
    
    // Initiate refund process
    initiateRefund(swap);
    swap.status = SwapStatus.Recovered;
}
```

## Fee Optimization

### Dynamic Relayer Fee Calculation

```solidity
function calculateOptimalRelayerFee(CrossChainSwapParams memory params) 
    internal 
    view 
    returns (uint256 relayerFeePct) 
{
    // Base fee percentage
    uint256 baseFee = 4; // 0.04%
    
    // Adjust based on:
    // 1. Bridge amount (larger amounts get better rates)
    if (params.amountIn > 100e18) baseFee = 3; // 0.03%
    if (params.amountIn > 1000e18) baseFee = 2; // 0.02%
    
    // 2. Network congestion
    uint256 congestionMultiplier = getNetworkCongestion(params.destinationChainId);
    baseFee = (baseFee * congestionMultiplier) / 100;
    
    // 3. Liquidity availability
    uint256 liquidityAdjustment = getLiquidityAdjustment(params.tokenIn, params.destinationChainId);
    baseFee = (baseFee * liquidityAdjustment) / 100;
    
    return baseFee;
}
```

### Speed vs Cost Optimization

```solidity
enum BridgeSpeed {
    Standard,  // ~10-15 minutes, lowest fees
    Fast,      // ~2-5 minutes, medium fees  
    Instant    // ~30 seconds, highest fees
}

function getBridgeQuote(
    address token,
    uint256 amount,
    uint256 destinationChain,
    BridgeSpeed speed
) external view returns (BridgeQuote memory) {
    BridgeQuote memory quote;
    
    quote.baseFee = getBaseFee(speed);
    quote.percentageFee = getPercentageFee(amount, speed);
    quote.estimatedTime = getEstimatedTime(destinationChain, speed);
    quote.totalFee = quote.baseFee + quote.percentageFee;
    
    return quote;
}
```

## Security Considerations

### Bridge Validation

```solidity
function validateBridgeParameters(BridgeParams calldata params) internal view {
    require(supportedTokens[params.token], "Unsupported token");
    require(supportedChains[params.destinationChainId], "Unsupported chain");
    require(params.amount >= minBridgeAmount, "Amount too small");
    require(params.amount <= maxBridgeAmount, "Amount too large");
    require(params.relayerFeePct <= maxRelayerFeePct, "Fee too high");
}
```

### Slippage Protection

```solidity
function executeBridgeWithSlippageProtection(
    BridgeParams calldata params,
    uint256 maxSlippageBPS
) external {
    uint256 expectedOutput = calculateExpectedOutput(params);
    uint256 minOutput = expectedOutput - (expectedOutput * maxSlippageBPS) / 10000;
    
    bytes32 bridgeId = acrossIntegration.initiateBridge(params);
    
    // Monitor for completion and validate output
    bridgeMonitor.setMinExpectedOutput(bridgeId, minOutput);
}
```

## Performance Metrics

### Bridge Success Rates

```solidity
struct BridgeMetrics {
    uint256 totalBridges;
    uint256 successfulBridges;
    uint256 failedBridges;
    uint256 averageCompletionTime;
    uint256 totalVolumeUSD;
}

function getBridgeMetrics(uint256 timeWindow) 
    external 
    view 
    returns (BridgeMetrics memory) 
{
    // Calculate metrics for specified time window
    // Used for monitoring and optimization
}
```

### Cost Effectiveness Analysis

```solidity
function analyzeCostEffectiveness(
    address token,
    uint256 amount,
    uint256 sourceChain,
    uint256 destinationChain
) external view returns (CostAnalysis memory) {
    uint256 bridgeCost = calculateBridgeFee(token, amount, destinationChain);
    uint256 gasSavings = calculateGasSavings(sourceChain, destinationChain);
    uint256 timeValue = calculateTimeValue(amount);
    
    return CostAnalysis({
        bridgeCost: bridgeCost,
        gasSavings: gasSavings,
        netSavings: gasSavings > bridgeCost ? gasSavings - bridgeCost : 0,
        timeValue: timeValue,
        recommendBridge: gasSavings > bridgeCost + timeValue
    });
}
```

## Testing Integration

### Mock Spoke Pool

```solidity
contract MockSpokePool {
    function depositV3(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes calldata message
    ) external {
        // Mock implementation for testing
        emit FundsDeposited(
            inputAmount,
            destinationChainId,
            destinationChainId,
            recipient,
            depositor,
            quoteTimestamp,
            inputToken,
            outputToken
        );
    }
}
```

This integration provides a robust, efficient, and secure bridge between the Gas Optimization Hook and Across Protocol, enabling seamless cross-chain optimization while maintaining high security standards and user experience.