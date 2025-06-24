// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {OptimizedBaseHook} from "./base/OptimizedBaseHook.sol";
import {IGasOptimizationHook} from "../interfaces/IGasOptimizationHook.sol";
import {ICostCalculator} from "../interfaces/ICostCalculator.sol";
import {ICrossChainManager} from "../interfaces/ICrossChainManager.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";
import {GasCalculations} from "../libraries/GasCalculations.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";

/// @title Gas Optimization Hook for Uniswap V4
contract GasOptimizationHook is OptimizedBaseHook, IGasOptimizationHook {
    using GasCalculations for uint256;

    ICostCalculator public costCalculator;
    ICrossChainManager public crossChainManager;
    
    // User preferences storage
    mapping(address => UserPreferences) private userPreferences;
    
    // System configuration
    uint256 public minSavingsThresholdBPS = Constants.DEFAULT_MIN_SAVINGS_BPS;
    uint256 public minAbsoluteSavingsUSD = Constants.DEFAULT_MIN_ABSOLUTE_SAVINGS_USD;
    uint256 public maxBridgeTime = Constants.MAX_BRIDGE_TIME;
    
    // Analytics storage
    mapping(address => uint256) public userTotalSavings;
    uint256 public totalSwapsOptimized;
    uint256 public totalSystemSavingsUSD;

    constructor(
        IPoolManager _poolManager,
        address initialOwner,
        address _costCalculator,
        address _crossChainManager
    ) OptimizedBaseHook(_poolManager, initialOwner) {
        costCalculator = ICostCalculator(_costCalculator);
        crossChainManager = ICrossChainManager(_crossChainManager);
    }

    /// @notice Internal hook called before a swap is executed
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) internal override whenNotPaused validPoolKey(key) nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        _validateSwapParams(params);
        
        SwapContext memory context = SwapContext({
            user: sender,
            poolKey: key,
            swapParams: params,
            currentChainId: _getCurrentChainId(),
            hookData: hookData
        });
        
        OptimizationQuote memory quote = _generateOptimizationQuote(context);
        
        if (quote.shouldOptimize) {
            // Initiate cross-chain swap
            _initiateCrossChainSwap(context, quote);
            
            // Update analytics
            _updateAnalytics(sender, quote.savingsUSD);
            
            emit Events.SwapOptimized(
                sender,
                Currency.unwrap(key.currency0),
                Currency.unwrap(key.currency1),
                uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified),
                quote.originalChainId,
                quote.optimizedChainId,
                quote.savingsUSD
            );
            
            // Return early to prevent local swap execution
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        } else {
            emit Events.SwapExecutedLocally(
                sender,
                Currency.unwrap(key.currency0),
                Currency.unwrap(key.currency1),
                uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified),
                "Savings below threshold"
            );
        }
        
        // Continue with normal swap execution
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @inheritdoc IGasOptimizationHook
    function getOptimizationQuote(
        SwapParams calldata params,
        PoolKey calldata key
    ) external view override returns (OptimizationQuote memory) {
        SwapContext memory context = SwapContext({
            user: msg.sender,
            poolKey: key,
            swapParams: params,
            currentChainId: _getCurrentChainId(),
            hookData: ""
        });
        
        return _generateOptimizationQuote(context);
    }

    /// @inheritdoc IGasOptimizationHook
    function setUserPreferences(UserPreferences calldata preferences) external override {
        userPreferences[msg.sender] = preferences;
    }

    /// @inheritdoc IGasOptimizationHook
    function getUserPreferences(address user) external view override returns (UserPreferences memory) {
        UserPreferences memory prefs = userPreferences[user];
        
        // Return defaults if not set
        if (prefs.minSavingsThresholdBPS == 0) {
            return UserPreferences({
                minSavingsThresholdBPS: minSavingsThresholdBPS,
                minAbsoluteSavingsUSD: minAbsoluteSavingsUSD,
                maxAcceptableBridgeTime: maxBridgeTime,
                enableCrossChainOptimization: true,
                enableUSDDisplay: true
            });
        }
        
        return prefs;
    }

    /// @inheritdoc IGasOptimizationHook
    function updateSystemConfiguration(
        uint256 _minSavingsThresholdBPS,
        uint256 _minAbsoluteSavingsUSD,
        uint256 _maxBridgeTime
    ) external override onlyOwner {
        minSavingsThresholdBPS = _minSavingsThresholdBPS;
        minAbsoluteSavingsUSD = _minAbsoluteSavingsUSD;
        maxBridgeTime = _maxBridgeTime;
        
        emit Events.ConfigurationUpdated(_minSavingsThresholdBPS, _minAbsoluteSavingsUSD, _maxBridgeTime);
    }

    /// @inheritdoc IGasOptimizationHook
    function pauseHook(bool pause) external override(IGasOptimizationHook, OptimizedBaseHook) onlyOwner {
        _hookPaused = pause;
        emit Events.EmergencyPauseToggled(pause, msg.sender);
    }

    /// @inheritdoc IGasOptimizationHook
    function isHookPaused() external view override returns (bool) {
        return _hookPaused;
    }


    /// @inheritdoc IGasOptimizationHook
    function getUserSavings(address user) external view override returns (uint256) {
        return userTotalSavings[user];
    }

    /// @inheritdoc IGasOptimizationHook
    function getSystemMetrics() external view override returns (
        uint256 totalSwapsOptimizedCount,
        uint256 totalSavingsUSD,
        uint256 averageSavingsPercentage
    ) {
        totalSwapsOptimizedCount = totalSwapsOptimized;
        totalSavingsUSD = totalSystemSavingsUSD;
        
        if (totalSwapsOptimized > 0) {
            // This is a simplified average calculation
            averageSavingsPercentage = (totalSystemSavingsUSD * Constants.BASIS_POINTS_DENOMINATOR) / totalSwapsOptimized;
        } else {
            averageSavingsPercentage = 0;
        }
    }

    function _generateOptimizationQuote(SwapContext memory context) private view returns (OptimizationQuote memory) {
        UserPreferences memory userPrefs = this.getUserPreferences(context.user);
        
        if (!userPrefs.enableCrossChainOptimization) {
            return OptimizationQuote({
                originalChainId: context.currentChainId,
                optimizedChainId: context.currentChainId,
                originalCostUSD: 0,
                optimizedCostUSD: 0,
                savingsUSD: 0,
                savingsPercentageBPS: 0,
                estimatedBridgeTime: 0,
                shouldOptimize: false
            });
        }
        
        // Find optimal chain
        ICostCalculator.OptimizationParams memory optimizationParams = ICostCalculator.OptimizationParams({
            tokenIn: Currency.unwrap(context.poolKey.currency0),
            tokenOut: Currency.unwrap(context.poolKey.currency1),
            amountIn: uint256(context.swapParams.amountSpecified > 0 ? context.swapParams.amountSpecified : -context.swapParams.amountSpecified),
            minSavingsThresholdBPS: userPrefs.minSavingsThresholdBPS,
            minAbsoluteSavingsUSD: userPrefs.minAbsoluteSavingsUSD,
            maxBridgeTime: userPrefs.maxAcceptableBridgeTime,
            excludeChains: new uint256[](0)
        });
        
        (uint256 optimalChainId, uint256 expectedSavingsUSD) = costCalculator.findOptimalChain(optimizationParams);
        
        if (optimalChainId == context.currentChainId) {
            return OptimizationQuote({
                originalChainId: context.currentChainId,
                optimizedChainId: context.currentChainId,
                originalCostUSD: 0,
                optimizedCostUSD: 0,
                savingsUSD: 0,
                savingsPercentageBPS: 0,
                estimatedBridgeTime: 0,
                shouldOptimize: false
            });
        }
        
        // Calculate costs for comparison
        ICostCalculator.TotalCost memory originalCost = costCalculator.calculateTotalCost(
            ICostCalculator.CostParams({
                chainId: context.currentChainId,
                tokenIn: Currency.unwrap(context.poolKey.currency0),
                tokenOut: Currency.unwrap(context.poolKey.currency1),
                amountIn: optimizationParams.amountIn,
                gasLimit: GasCalculations.estimateSwapGas(),
                user: context.user
            })
        );
        
        ICostCalculator.TotalCost memory optimizedCost = costCalculator.calculateTotalCost(
            ICostCalculator.CostParams({
                chainId: optimalChainId,
                tokenIn: Currency.unwrap(context.poolKey.currency0),
                tokenOut: Currency.unwrap(context.poolKey.currency1),
                amountIn: optimizationParams.amountIn,
                gasLimit: GasCalculations.calculateCrossChainGasUsage(true),
                user: context.user
            })
        );
        
        uint256 savingsPercentageBPS = originalCost.totalCostUSD.calculateSavingsPercent(optimizedCost.totalCostUSD);
        
        return OptimizationQuote({
            originalChainId: context.currentChainId,
            optimizedChainId: optimalChainId,
            originalCostUSD: originalCost.totalCostUSD,
            optimizedCostUSD: optimizedCost.totalCostUSD,
            savingsUSD: expectedSavingsUSD,
            savingsPercentageBPS: savingsPercentageBPS,
            estimatedBridgeTime: optimizedCost.executionTime,
            shouldOptimize: true
        });
    }

    function _initiateCrossChainSwap(SwapContext memory context, OptimizationQuote memory quote) private {
        ICrossChainManager.CrossChainSwapParams memory crossChainParams = ICrossChainManager.CrossChainSwapParams({
            user: context.user,
            tokenIn: Currency.unwrap(context.poolKey.currency0),
            tokenOut: Currency.unwrap(context.poolKey.currency1),
            amountIn: uint256(context.swapParams.amountSpecified > 0 ? context.swapParams.amountSpecified : -context.swapParams.amountSpecified),
            minAmountOut: 0, // Will be calculated by CrossChainManager
            sourceChainId: context.currentChainId,
            destinationChainId: quote.optimizedChainId,
            deadline: _calculateDeadline(quote.estimatedBridgeTime + 300), // Add 5 minute buffer
            swapData: context.hookData
        });
        
        crossChainManager.initiateCrossChainSwap(crossChainParams);
    }

    function _updateAnalytics(address user, uint256 savingsUSD) private {
        userTotalSavings[user] += savingsUSD;
        totalSwapsOptimized += 1;
        totalSystemSavingsUSD += savingsUSD;
    }
}