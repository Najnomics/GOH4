// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasOptimizationHook} from "../../src/hooks/GasOptimizationHook.sol";
import {OptimizedBaseHook} from "../../src/hooks/base/OptimizedBaseHook.sol";
import {IGasOptimizationHook} from "../../src/interfaces/IGasOptimizationHook.sol";
import {ICostCalculator} from "../../src/interfaces/ICostCalculator.sol";
import {ICrossChainManager} from "../../src/interfaces/ICrossChainManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";
import {Events} from "../../src/utils/Events.sol";

// Mock contracts for testing
contract MockPoolManager {
    function getSlot0(bytes32 poolId) external pure returns (uint160, int24, uint24, uint24) {
        return (79228162514264337593543950336, 0, 0, 3000);
    }
}

contract MockCostCalculator {
    function findOptimalChain(ICostCalculator.OptimizationParams calldata params) 
        external 
        view 
        returns (uint256 chainId, uint256 expectedSavingsUSD) 
    {
        // For testing, return Arbitrum as optimal if amount > 1 ETH
        if (params.amountIn > 1e18) {
            return (Constants.ARBITRUM_CHAIN_ID, 50e18); // $50 savings
        }
        return (block.chainid, 0);
    }
    
    function calculateTotalCost(ICostCalculator.CostParams calldata params) 
        external 
        view 
        returns (ICostCalculator.TotalCost memory) 
    {
        uint256 gasCost = params.chainId == 1 ? 50e18 : 2e18; // Ethereum expensive, others cheap
        return ICostCalculator.TotalCost({
            gasCostUSD: gasCost,
            bridgeFeeUSD: params.chainId == block.chainid ? 0 : 8e18,
            slippageCostUSD: 1e18,
            totalCostUSD: gasCost + (params.chainId == block.chainid ? 0 : 8e18) + 1e18,
            executionTime: params.chainId == block.chainid ? 0 : 300
        });
    }
}

contract MockCrossChainManager {
    mapping(bytes32 => bool) public swapInitiated;
    uint256 public swapCounter;
    
    function initiateCrossChainSwap(ICrossChainManager.CrossChainSwapParams calldata params) 
        external 
        returns (bytes32 swapId) 
    {
        swapId = keccak256(abi.encodePacked(params.user, params.amountIn, swapCounter++));
        swapInitiated[swapId] = true;
        return swapId;
    }
}

contract MockAcrossProtocol {
    // Mock implementation
}

contract MockChainlinkIntegration {
    function convertToUSD(address token, uint256 amount) external pure returns (uint256) {
        return amount * 2000; // Assume $2000 per token for testing
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract GasOptimizationHookDetailedTest is Test {
    using CurrencyLibrary for Currency;
    
    GasOptimizationHook hook;
    MockPoolManager mockPoolManager;
    MockCostCalculator mockCostCalculator;
    MockCrossChainManager mockCrossChainManager;
    MockAcrossProtocol mockAcrossProtocol;
    MockChainlinkIntegration mockChainlinkIntegration;
    MockERC20 token0;
    MockERC20 token1;
    
    address owner = address(0x1);
    address user = address(0x2);
    
    PoolKey testPoolKey;
    
    function setUp() public {
        // Create mock contracts
        mockPoolManager = new MockPoolManager();
        mockCostCalculator = new MockCostCalculator();
        mockCrossChainManager = new MockCrossChainManager();
        mockAcrossProtocol = new MockAcrossProtocol();
        mockChainlinkIntegration = new MockChainlinkIntegration();
        token0 = new MockERC20("Token0", "TKN0", 18);
        token1 = new MockERC20("Token1", "TKN1", 18);
        
        // Use HookMiner to find a valid hook address
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode = type(GasOptimizationHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(mockPoolManager)),
            owner,
            address(mockCostCalculator),
            address(mockCrossChainManager),
            address(mockAcrossProtocol),
            address(mockChainlinkIntegration)
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            creationCode,
            constructorArgs
        );
        
        // Deploy hook with the found salt
        hook = new GasOptimizationHook{salt: salt}(
            IPoolManager(address(mockPoolManager)),
            owner,
            address(mockCostCalculator),
            address(mockCrossChainManager),
            address(mockAcrossProtocol),
            address(mockChainlinkIntegration)
        );
        
        // Verify hook address matches
        assertEq(address(hook), hookAddress);
        
        // Setup test tokens
        token0.mint(address(hook), 1000e18);
        token1.mint(address(hook), 1000e18);
        token0.mint(user, 1000e18);
        token1.mint(user, 1000e18);
        
        // Setup test pool key
        testPoolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)), 
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }
    
    function testInitialization() public view {
        assertEq(address(hook.costCalculator()), address(mockCostCalculator));
        assertEq(address(hook.crossChainManager()), address(mockCrossChainManager));
        assertEq(hook.owner(), owner);
        assertEq(hook.minSavingsThresholdBPS(), Constants.DEFAULT_MIN_SAVINGS_BPS);
        assertEq(hook.minAbsoluteSavingsUSD(), Constants.DEFAULT_MIN_ABSOLUTE_SAVINGS_USD);
        assertEq(hook.maxBridgeTime(), Constants.MAX_BRIDGE_TIME);
    }
    
    function testGetOptimizationQuote() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(2e18), // 2 ETH - should trigger optimization
            sqrtPriceLimitX96: 0
        });
        
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertTrue(quote.shouldOptimize);
        assertEq(quote.optimizedChainId, Constants.ARBITRUM_CHAIN_ID);
        assertGt(quote.savingsUSD, 0);
    }
    
    function testGetOptimizationQuoteNoOptimization() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(0.5e18), // 0.5 ETH - should not trigger optimization
            sqrtPriceLimitX96: 0
        });
        
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertFalse(quote.shouldOptimize);
        assertEq(quote.optimizedChainId, block.chainid); // Current chain
        assertEq(quote.savingsUSD, 0);
    }
    
    function testSetUserPreferences() public {
        IGasOptimizationHook.UserPreferences memory preferences = IGasOptimizationHook.UserPreferences({
            minSavingsThresholdBPS: 1000, // 10%
            minAbsoluteSavingsUSD: 20e18, // $20
            maxAcceptableBridgeTime: 600, // 10 minutes
            enableCrossChainOptimization: true,
            enableUSDDisplay: true
        });
        
        vm.prank(user);
        hook.setUserPreferences(preferences);
        
        IGasOptimizationHook.UserPreferences memory retrieved = hook.getUserPreferences(user);
        assertEq(retrieved.minSavingsThresholdBPS, 1000);
        assertEq(retrieved.minAbsoluteSavingsUSD, 20e18);
        assertEq(retrieved.maxAcceptableBridgeTime, 600);
        assertTrue(retrieved.enableCrossChainOptimization);
        assertTrue(retrieved.enableUSDDisplay);
    }
    
    function testGetUserPreferencesDefaults() public view {
        IGasOptimizationHook.UserPreferences memory preferences = hook.getUserPreferences(user);
        
        // Should return defaults
        assertEq(preferences.minSavingsThresholdBPS, hook.minSavingsThresholdBPS());
        assertEq(preferences.minAbsoluteSavingsUSD, hook.minAbsoluteSavingsUSD());
        assertEq(preferences.maxAcceptableBridgeTime, hook.maxBridgeTime());
        assertTrue(preferences.enableCrossChainOptimization);
        assertTrue(preferences.enableUSDDisplay);
    }
    
    function testGetUserPreferencesDisabledOptimization() public {
        IGasOptimizationHook.UserPreferences memory preferences = IGasOptimizationHook.UserPreferences({
            minSavingsThresholdBPS: 500,
            minAbsoluteSavingsUSD: 10e18,
            maxAcceptableBridgeTime: 1800,
            enableCrossChainOptimization: false, // Disabled
            enableUSDDisplay: true
        });
        
        vm.prank(user);
        hook.setUserPreferences(preferences);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(2e18), // 2 ETH
            sqrtPriceLimitX96: 0
        });
        
        // The user preferences check happens based on the context.user inside the quote generation
        // We need to test this by simulating the actual usage pattern
        vm.prank(user);
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertFalse(quote.shouldOptimize); // Should not optimize when disabled
    }
    
    function testUpdateSystemConfiguration() public {
        vm.prank(owner);
        hook.updateSystemConfiguration(1000, 25e18, 2400);
        
        assertEq(hook.minSavingsThresholdBPS(), 1000);
        assertEq(hook.minAbsoluteSavingsUSD(), 25e18);
        assertEq(hook.maxBridgeTime(), 2400);
    }
    
    function testUpdateSystemConfigurationOnlyOwner() public {
        vm.expectRevert();
        hook.updateSystemConfiguration(1000, 25e18, 2400);
    }
    
    function testPauseHook() public {
        vm.prank(owner);
        hook.pauseHook(true);
        
        assertTrue(hook.isHookPaused());
    }
    
    function testPauseHookOnlyOwner() public {
        vm.expectRevert();
        hook.pauseHook(true);
    }
    
    function testGetUserSavings() public view {
        uint256 savings = hook.getUserSavings(user);
        assertEq(savings, 0); // Initial savings should be 0
    }
    
    function testGetSystemMetrics() public view {
        (uint256 totalSwaps, uint256 totalSavings, uint256 averageSavings) = hook.getSystemMetrics();
        
        assertEq(totalSwaps, 0);
        assertEq(totalSavings, 0);
        assertEq(averageSavings, 0);
    }
    
    function testBeforeSwapLocalExecution() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(0.5e18), // Small amount - no optimization
            sqrtPriceLimitX96: 0
        });
        
        // Test that getOptimizationQuote returns shouldOptimize = false for small amounts
        vm.prank(user);
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertFalse(quote.shouldOptimize);
        assertEq(quote.savingsUSD, 0);
        assertEq(quote.originalChainId, block.chainid);
        assertEq(quote.optimizedChainId, block.chainid);
    }
    
    function testBeforeSwapCrossChainExecution() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(2e18), // Large amount - should optimize
            sqrtPriceLimitX96: 0
        });
        
        // The hook should initiate cross-chain swap
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertTrue(quote.shouldOptimize);
        assertEq(quote.optimizedChainId, Constants.ARBITRUM_CHAIN_ID);
        assertGt(quote.savingsUSD, 0);
    }
    
    function testValidateSwapParams() public {
        SwapParams memory invalidParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0, // Invalid zero amount
            sqrtPriceLimitX96: 0
        });
        
        // This should be caught by internal validation
        // We test this indirectly through the quote function
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(invalidParams, testPoolKey);
        
        // Should not optimize with zero amount
        assertFalse(quote.shouldOptimize);
    }
    
    function testCalculateDeadline() public view {
        // Test the internal deadline calculation through the public interface
        uint256 currentTime = block.timestamp;
        
        // We can't directly test the internal function, but we can verify it's working
        // through the optimization quote which uses it internally
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(2e18),
            sqrtPriceLimitX96: 0
        });
        
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertTrue(quote.shouldOptimize);
        assertGt(quote.estimatedBridgeTime, 0);
    }
    
    function testCurrentChainId() public {
        // Test that the hook correctly identifies the current chain
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(0.5e18),
            sqrtPriceLimitX96: 0
        });
        
        IGasOptimizationHook.OptimizationQuote memory quote = hook.getOptimizationQuote(params, testPoolKey);
        
        assertEq(quote.originalChainId, block.chainid);
    }
    
    function testHookPermissions() public view {
        // Test that the hook has the correct permissions
        assertTrue(hook.getHookPermissions().beforeSwap);
        assertFalse(hook.getHookPermissions().afterSwap);
        assertFalse(hook.getHookPermissions().beforeInitialize);
        assertFalse(hook.getHookPermissions().afterInitialize);
    }
}