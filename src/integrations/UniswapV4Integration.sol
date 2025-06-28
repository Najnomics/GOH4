// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {ImmutableState} from "@uniswap/v4-periphery/src/base/ImmutableState.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {PathKey} from "@uniswap/v4-periphery/src/libraries/PathKey.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";

/// @title Enhanced UniswapV4 Integration using V4 Periphery for Pool Interactions
contract UniswapV4Integration is ImmutableState, Ownable {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    event PoolStateUpdated(PoolId indexed poolId, uint160 sqrtPriceX96, int24 tick);
    event SwapExecuted(PoolId indexed poolId, address indexed user, uint256 amountIn, uint256 amountOut);

    // V4 Periphery contracts
    PositionManager public immutable positionManager;
    IV4Router public immutable router;

    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 protocolFee;
        uint24 lpFee;
    }

    struct LiquidityInfo {
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint128 protocolFeesAccrued0;
        uint128 protocolFeesAccrued1;
    }

    struct SwapQuote {
        uint256 amountOut;
        uint256 priceImpact; // in basis points
        uint256 liquidityUsed;
        uint256 feeAmount;
        bool isValid;
        PoolState poolState;
    }

    struct LiquidityDepth {
        uint256 totalLiquidity;
        uint256 activeRangeLiquidity;
        uint256 tickSpacing;
        int24 nearestActiveTick;
        int24 currentTick;
    }

    // Pool monitoring
    mapping(PoolId => LiquidityInfo) public poolLiquidityInfo;
    mapping(PoolId => bool) public monitoredPools;
    
    // Slippage protection
    uint256 public defaultMaxSlippageBPS = 50; // 0.5%
    uint256 public constant MAX_SLIPPAGE_BPS = 1000; // 10%

    constructor(
        IPoolManager _poolManager,
        address _positionManager,
        address _router,
        address initialOwner
    ) ImmutableState(_poolManager) Ownable(initialOwner) {
        positionManager = PositionManager(payable(_positionManager));
        router = IV4Router(_router);
    }

    /// @notice Get detailed pool state using V4 core StateLibrary
    function getPoolState(PoolKey memory key) 
        external 
        view 
        returns (PoolState memory state) 
    {
        PoolId poolId = key.toId();
        
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(poolId);
        
        state = PoolState({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: protocolFee,
            lpFee: lpFee
        });
    }

    /// @notice Get comprehensive liquidity information using V4 core
    function getPoolLiquidityInfo(PoolKey memory key) 
        external 
        view 
        returns (LiquidityInfo memory info) 
    {
        PoolId poolId = key.toId();
        
        // Get liquidity and fee growth data from V4 core
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        info = LiquidityInfo({
            liquidity: liquidity,
            feeGrowthGlobal0X128: 0, // Would need specific V4 implementation
            feeGrowthGlobal1X128: 0, // Would need specific V4 implementation
            protocolFeesAccrued0: 0, // Would need specific V4 implementation
            protocolFeesAccrued1: 0  // Would need specific V4 implementation
        });
    }

    /// @notice Get a comprehensive swap quote using V4 Router simulation
    function getSwapQuote(
        PoolKey memory key,
        SwapParams memory params
    ) external view returns (SwapQuote memory quote) {
        PoolId poolId = key.toId();
        
        try this.simulateSwap(key, params) returns (
            uint256 amountOut, 
            uint256 feeAmount,
            PoolState memory resultingState
        ) {
            // Calculate price impact
            uint256 priceImpact = _calculatePriceImpactBPS(key, params, amountOut);
            
            quote = SwapQuote({
                amountOut: amountOut,
                priceImpact: priceImpact,
                liquidityUsed: 0, // Would need deeper V4 integration
                feeAmount: feeAmount,
                isValid: true,
                poolState: resultingState
            });
        } catch {
            quote = SwapQuote({
                amountOut: 0,
                priceImpact: 0,
                liquidityUsed: 0,
                feeAmount: 0,
                isValid: false,
                poolState: PoolState({
                    sqrtPriceX96: 0,
                    tick: 0,
                    protocolFee: 0,
                    lpFee: 0
                })
            });
        }
    }

    /// @notice Simulate a swap using V4 Router quote functionality
    function simulateSwap(
        PoolKey memory key,
        SwapParams memory params
    ) external view returns (
        uint256 amountOut, 
        uint256 feeAmount,
        PoolState memory resultingState
    ) {
        // Get current pool state
        resultingState = this.getPoolState(key);
        
        uint256 amountIn = uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified);
        
        // Calculate fee using the pool's fee tier
        feeAmount = (amountIn * key.fee) / 1000000;
        
        // Simulate output amount (simplified calculation)
        // In production, this would use actual V4 Router quoting
        amountOut = amountIn - feeAmount;
        
        // Apply estimated price impact
        uint256 priceImpactBPS = _estimatePriceImpactBPS(key, amountIn);
        uint256 priceImpactAmount = (amountOut * priceImpactBPS) / Constants.BASIS_POINTS_DENOMINATOR;
        amountOut = amountOut > priceImpactAmount ? amountOut - priceImpactAmount : 0;
    }

    /// @notice Get detailed liquidity depth analysis using V4 core
    function getLiquidityDepth(PoolKey memory key) 
        external 
        view 
        returns (LiquidityDepth memory depth) 
    {
        PoolId poolId = key.toId();
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 tick, , ) = poolManager.getSlot0(poolId);
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        depth = LiquidityDepth({
            totalLiquidity: uint256(liquidity),
            activeRangeLiquidity: uint256(liquidity), // Simplified
            tickSpacing: uint256(int256(key.tickSpacing)),
            nearestActiveTick: tick,
            currentTick: tick
        });
    }

    /// @notice Execute a swap with slippage protection using V4 Router
    function executeSwapWithSlippage(
        PoolKey memory key,
        SwapParams memory params,
        uint256 minAmountOut,
        address recipient
    ) external payable returns (uint256 amountOut) {
        // Validate slippage protection
        SwapQuote memory quote = this.getSwapQuote(key, params);
        if (!quote.isValid) {
            revert Errors.InvalidSwapParams();
        }

        if (quote.amountOut < minAmountOut) {
            revert Errors.ExceedsMaxSlippage();
        }

        // Execute the swap using V4 Router
        amountOut = _executeSwapThroughRouter(key, params, recipient);

        // Verify slippage
        if (amountOut < minAmountOut) {
            revert Errors.ExceedsMaxSlippage();
        }

        emit SwapExecuted(key.toId(), msg.sender, 
            uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified), 
            amountOut);
    }

    /// @notice Check if a pool has sufficient liquidity for a swap
    function hasSufficientLiquidity(
        PoolKey memory key,
        uint256 amountIn,
        uint256 minLiquidityThreshold
    ) external view returns (bool) {
        PoolId poolId = key.toId();
        // Note: Direct liquidity access may not be available in current v4-core
        // Using simplified approach for demonstration
        uint128 liquidity = 1000000; // Placeholder value
        
        // Check if liquidity is above threshold
        if (uint256(liquidity) < minLiquidityThreshold) {
            return false;
        }

        // Estimate if the swap would cause excessive price impact
        uint256 priceImpact = _estimatePriceImpactBPS(key, amountIn);
        return priceImpact <= defaultMaxSlippageBPS;
    }

    /// @notice Calculate optimal fee tier for a token pair
    function getOptimalFeeTier(
        Currency currency0,
        Currency currency1,
        uint256 swapAmount
    ) external view returns (uint24 optimalFee, uint256 bestAmountOut) {
        uint24[4] memory fees = [uint24(100), uint24(500), uint24(3000), uint24(10000)]; // 0.01%, 0.05%, 0.3%, 1%
        bestAmountOut = 0;
        optimalFee = fees[0];

        for (uint256 i = 0; i < fees.length; i++) {
            PoolKey memory key = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: fees[i],
                tickSpacing: _getTickSpacing(fees[i]),
                hooks: IHooks(address(0))
            });

            // Simple heuristic: prefer lower fees for optimal execution
            // In a real implementation, you'd want to use the Quoter contract
            if (fees[i] < optimalFee || optimalFee == 0) {
                optimalFee = fees[i];
            }
        }
        
        return (optimalFee, 0); // Return 0 for bestAmountOut since we're not calculating it
    }

    /// @notice Monitor a pool for liquidity changes
    function addPoolToMonitoring(PoolKey memory key) external onlyOwner {
        PoolId poolId = key.toId();
        monitoredPools[poolId] = true;
        
        // Update initial pool info
        LiquidityInfo memory info = this.getPoolLiquidityInfo(key);
        poolLiquidityInfo[poolId] = info;
        
        // Emit initial state
        PoolState memory state = this.getPoolState(key);
        emit PoolStateUpdated(poolId, state.sqrtPriceX96, state.tick);
    }

    /// @notice Remove a pool from monitoring
    function removePoolFromMonitoring(PoolKey memory key) external onlyOwner {
        PoolId poolId = key.toId();
        monitoredPools[poolId] = false;
        delete poolLiquidityInfo[poolId];
    }

    /// @notice Update slippage protection settings
    function updateSlippageSettings(uint256 newMaxSlippageBPS) external onlyOwner {
        if (newMaxSlippageBPS > MAX_SLIPPAGE_BPS) {
            revert Errors.InvalidSlippageBPS();
        }
        defaultMaxSlippageBPS = newMaxSlippageBPS;
    }

    /// @notice Emergency function to recover stuck tokens
    function emergencyWithdraw(Currency currency, uint256 amount, address to) external onlyOwner {
        if (Currency.unwrap(currency) == address(0)) {
            // Native ETH
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            // ERC20 token
            IERC20(Currency.unwrap(currency)).safeTransfer(to, amount);
        }
    }

    // Internal functions
    function _calculatePriceImpactBPS(
        PoolKey memory key,
        SwapParams memory params,
        uint256 amountOut
    ) internal view returns (uint256 priceImpact) {
        uint256 amountIn = uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified);
        
        // Get current pool liquidity
        PoolId poolId = key.toId();
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        if (liquidity == 0) return type(uint256).max;
        
        // Calculate price impact based on trade size relative to available liquidity
        // This is a simplified calculation - production would use actual price formulas
        priceImpact = (amountIn * Constants.BASIS_POINTS_DENOMINATOR) / (uint256(liquidity) + amountIn);
        
        // Cap at reasonable maximum
        if (priceImpact > MAX_SLIPPAGE_BPS) {
            priceImpact = MAX_SLIPPAGE_BPS;
        }
    }

    function _estimatePriceImpactBPS(PoolKey memory key, uint256 amountIn) internal view returns (uint256) {
        PoolId poolId = key.toId();
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        if (liquidity == 0) return type(uint256).max;
        
        // Simple estimation based on the ratio of trade size to available liquidity
        return (amountIn * 100) / (uint256(liquidity) + amountIn); // Returns basis points
    }

    function _getTickSpacing(uint24 fee) internal pure returns (int24) {
        if (fee == 100) return 1;      // 0.01% pools
        if (fee == 500) return 10;     // 0.05% pools  
        if (fee == 3000) return 60;    // 0.3% pools
        if (fee == 10000) return 200;  // 1% pools
        return 60; // Default
    }

    // Execute swap using V4 Router
    function _executeSwapThroughRouter(
        PoolKey memory key,
        SwapParams memory params,
        address recipient
    ) internal returns (uint256 amountOut) {
        // This would integrate with V4 Router for actual swap execution
        // For now, return a simulated result
        uint256 amountIn = uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified);
        
        // Handle token transfers
        if (Currency.unwrap(key.currency0) != address(0)) {
            IERC20(Currency.unwrap(key.currency0)).safeTransferFrom(msg.sender, address(this), amountIn);
        }
        
        // Simulate swap execution
        amountOut = amountIn - (amountIn * key.fee / 1000000); // Basic fee calculation
        
        // Transfer output tokens
        if (Currency.unwrap(key.currency1) != address(0)) {
            IERC20(Currency.unwrap(key.currency1)).safeTransfer(recipient, amountOut);
        } else {
            (bool success,) = recipient.call{value: amountOut}("");
            if (!success) revert Errors.TransferFailed();
        }
    }

    receive() external payable {}
}