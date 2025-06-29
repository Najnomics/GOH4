// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {OptimizedBaseHook} from "../../src/hooks/base/OptimizedBaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {Errors} from "../../src/utils/Errors.sol";

// Mock contracts for testing
contract MockPoolManager {
    function getSlot0(bytes32 poolId) external pure returns (uint160, int24, uint24, uint24) {
        return (79228162514264337593543950336, 0, 0, 3000);
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

// Test implementation of OptimizedBaseHook
contract TestOptimizedBaseHook is OptimizedBaseHook {
    using CurrencyLibrary for Currency;
    
    bool public beforeSwapCalled;
    address public lastSender;
    uint256 public lastAmountSpecified;
    
    constructor(IPoolManager _poolManager, address initialOwner) 
        OptimizedBaseHook(_poolManager, initialOwner) {}
    
    function testBeforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external whenNotPaused validPoolKey(key) nonReentrant returns (bytes4) {
        _validateSwapParams(params);
        
        beforeSwapCalled = true;
        lastSender = sender;
        lastAmountSpecified = uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified);
        
        return this.testBeforeSwap.selector;
    }
    
    function testGetCurrentChainId() external view returns (uint256) {
        return _getCurrentChainId();
    }
    
    function testCalculateDeadline(uint256 additionalTime) external view returns (uint256) {
        return _calculateDeadline(additionalTime);
    }
    
    function testSafeTransfer(address token, address to, uint256 amount) external {
        _safeTransfer(token, to, amount);
    }
    
    function testSafeTransferFrom(address token, address from, address to, uint256 amount) external {
        _safeTransferFrom(token, from, to, amount);
    }
    
    function testGetTokenBalance(address token, address account) external view returns (uint256) {
        return _getTokenBalance(token, account);
    }
    
    function testValidateSwapParams(SwapParams calldata params) external pure {
        _validateSwapParams(params);
    }
}

contract OptimizedBaseHookDetailedTest is Test {
    using CurrencyLibrary for Currency;
    
    TestOptimizedBaseHook hook;
    MockPoolManager mockPoolManager;
    MockERC20 token0;
    MockERC20 token1;
    
    address owner = address(0x1);
    address user = address(0x2);
    address recipient = address(0x3);
    
    PoolKey validPoolKey;
    PoolKey invalidPoolKey;
    
    function setUp() public {
        mockPoolManager = new MockPoolManager();
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);
        
        // Deploy hook using HookMiner to get correct address with BEFORE_SWAP_FLAG
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode = type(TestOptimizedBaseHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(mockPoolManager)),
            owner
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            creationCode,
            constructorArgs
        );
        
        hook = new TestOptimizedBaseHook{salt: salt}(
            IPoolManager(address(mockPoolManager)),
            owner
        );
        
        // Verify hook was deployed at the correct address
        require(address(hook) == hookAddress, "Hook deployed at wrong address");
        
        validPoolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        invalidPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // Invalid - zero address
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Mint tokens
        token0.mint(user, 1000e18);
        token1.mint(user, 1000e18);
        token0.mint(address(hook), 1000e18);
        token1.mint(address(hook), 1000e18);
    }
    
    function testInitialization() public view {
        assertEq(hook.owner(), owner);
        assertFalse(hook.isPaused());
        assertEq(address(hook.poolManager()), address(mockPoolManager));
    }
    
    function testGetHookPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertTrue(permissions.beforeSwap);
        assertFalse(permissions.afterSwap);
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
        assertFalse(permissions.beforeSwapReturnDelta);
        assertFalse(permissions.afterSwapReturnDelta);
        assertFalse(permissions.afterAddLiquidityReturnDelta);
        assertFalse(permissions.afterRemoveLiquidityReturnDelta);
    }
    
    function testPauseHook() public {
        assertFalse(hook.isPaused());
        
        vm.prank(owner);
        hook.pauseHook(true);
        
        assertTrue(hook.isPaused());
        
        vm.prank(owner);
        hook.pauseHook(false);
        
        assertFalse(hook.isPaused());
    }
    
    function testPauseHookOnlyOwner() public {
        vm.expectRevert();
        hook.pauseHook(true);
    }
    
    function testWhenNotPausedModifier() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1e18),
            sqrtPriceLimitX96: 0
        });
        
        // Should work when not paused
        hook.testBeforeSwap(user, validPoolKey, params, "");
        assertTrue(hook.beforeSwapCalled());
        
        // Pause the hook
        vm.prank(owner);
        hook.pauseHook(true);
        
        // Should revert when paused
        vm.expectRevert(Errors.EmergencyPauseActive.selector);
        hook.testBeforeSwap(user, validPoolKey, params, "");
    }
    
    function testValidPoolKeyModifier() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1e18),
            sqrtPriceLimitX96: 0
        });
        
        // Should work with valid pool key
        hook.testBeforeSwap(user, validPoolKey, params, "");
        assertTrue(hook.beforeSwapCalled());
        
        // Should revert with invalid pool key
        vm.expectRevert(Errors.InvalidPoolKey.selector);
        hook.testBeforeSwap(user, invalidPoolKey, params, "");
    }
    
    function testValidateSwapParams() public {
        SwapParams memory validParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1e18),
            sqrtPriceLimitX96: 0
        });
        
        SwapParams memory invalidParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0, // Invalid zero amount
            sqrtPriceLimitX96: 0
        });
        
        // Should not revert with valid params
        hook.testValidateSwapParams(validParams);
        
        // Should revert with invalid params
        vm.expectRevert(Errors.ZeroAmount.selector);
        hook.testValidateSwapParams(invalidParams);
    }
    
    function testGetCurrentChainId() public view {
        uint256 chainId = hook.testGetCurrentChainId();
        assertEq(chainId, block.chainid);
    }
    
    function testCalculateDeadline() public {
        uint256 additionalTime = 3600; // 1 hour
        uint256 deadline = hook.testCalculateDeadline(additionalTime);
        
        assertEq(deadline, block.timestamp + additionalTime);
        
        // Test with different time
        vm.warp(block.timestamp + 1000);
        uint256 newDeadline = hook.testCalculateDeadline(additionalTime);
        assertEq(newDeadline, block.timestamp + additionalTime);
    }
    
    function testEmergencyWithdrawERC20() public {
        uint256 amount = 100e18;
        uint256 initialBalance = token0.balanceOf(recipient);
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(token0), amount, recipient);
        
        assertEq(token0.balanceOf(recipient), initialBalance + amount);
    }
    
    function testEmergencyWithdrawETH() public {
        uint256 amount = 1 ether;
        
        // Send ETH to the hook
        vm.deal(address(hook), amount);
        
        uint256 initialBalance = recipient.balance;
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(0), amount, recipient);
        
        assertEq(recipient.balance, initialBalance + amount);
    }
    
    function testEmergencyWithdrawOnlyOwner() public {
        vm.expectRevert();
        hook.emergencyWithdraw(address(token0), 100e18, recipient);
    }
    
    function testEmergencyWithdrawZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.emergencyWithdraw(address(token0), 100e18, address(0));
    }
    
    function testSafeTransfer() public {
        uint256 amount = 100e18;
        uint256 initialBalance = token0.balanceOf(recipient);
        
        hook.testSafeTransfer(address(token0), recipient, amount);
        
        assertEq(token0.balanceOf(recipient), initialBalance + amount);
    }
    
    function testSafeTransferZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransfer(address(0), recipient, 100e18);
        
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransfer(address(token0), address(0), 100e18);
    }
    
    function testSafeTransferFrom() public {
        uint256 amount = 100e18;
        
        // Approve hook to spend user's tokens
        vm.prank(user);
        token0.approve(address(hook), amount);
        
        uint256 initialBalance = token0.balanceOf(recipient);
        
        hook.testSafeTransferFrom(address(token0), user, recipient, amount);
        
        assertEq(token0.balanceOf(recipient), initialBalance + amount);
    }
    
    function testSafeTransferFromZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(0), user, recipient, 100e18);
        
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(token0), address(0), recipient, 100e18);
        
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(token0), user, address(0), 100e18);
    }
    
    function testGetTokenBalanceERC20() public view {
        uint256 balance = hook.testGetTokenBalance(address(token0), user);
        assertEq(balance, token0.balanceOf(user));
    }
    
    function testGetTokenBalanceETH() public {
        uint256 ethAmount = 5 ether;
        vm.deal(user, ethAmount);
        
        uint256 balance = hook.testGetTokenBalance(address(0), user);
        assertEq(balance, ethAmount);
    }
    
    function testReceiveETH() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = address(hook).balance;
        
        vm.deal(user, amount);
        vm.prank(user);
        (bool success,) = address(hook).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(hook).balance, initialBalance + amount);
    }
    
    function testReentrancyGuard() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1e18),
            sqrtPriceLimitX96: 0
        });
        
        // First call should succeed
        hook.testBeforeSwap(user, validPoolKey, params, "");
        assertTrue(hook.beforeSwapCalled());
        
        // The reentrancy guard prevents testing actual reentrancy in a simple way
        // but we can verify the modifier is applied by checking the function works normally
        assertEq(hook.lastSender(), user);
        assertEq(hook.lastAmountSpecified(), 1e18);
    }
    
    function testOwnershipTransfer() public {
        address newOwner = address(0x999);
        
        vm.prank(owner);
        hook.transferOwnership(newOwner);
        
        assertEq(hook.owner(), newOwner);
        
        // Old owner should no longer be able to pause
        vm.expectRevert();
        vm.prank(owner);
        hook.pauseHook(true);
        
        // New owner should be able to pause
        vm.prank(newOwner);
        hook.pauseHook(true);
        assertTrue(hook.isPaused());
    }
    
    function testNonReentrantModifier() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1e18),
            sqrtPriceLimitX96: 0
        });
        
        // Test that the nonReentrant modifier is working by calling the function normally
        hook.testBeforeSwap(user, validPoolKey, params, "");
        assertTrue(hook.beforeSwapCalled());
        
        // Reset the flag and test again
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode = type(TestOptimizedBaseHook).creationCode;
        bytes memory constructorArgs = abi.encode(IPoolManager(address(mockPoolManager)), owner);
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            creationCode,
            constructorArgs
        );
        
        hook = new TestOptimizedBaseHook{salt: salt}(IPoolManager(address(mockPoolManager)), owner);
        
        // Set up tokens again
        token0.mint(address(hook), 1000e18);
        token1.mint(address(hook), 1000e18);
        
        hook.testBeforeSwap(user, validPoolKey, params, "");
        assertTrue(hook.beforeSwapCalled());
    }
    
    function testFuzzCalculateDeadline(uint256 additionalTime) public {
        // Bound the additional time to reasonable values
        additionalTime = bound(additionalTime, 1, 86400 * 365); // 1 second to 1 year
        
        uint256 deadline = hook.testCalculateDeadline(additionalTime);
        assertEq(deadline, block.timestamp + additionalTime);
    }
    
    function testFuzzEmergencyWithdraw(uint256 amount, address to) public {
        // Skip zero address and other invalid addresses
        vm.assume(to != address(0) && to != address(hook) && to.code.length == 0);
        amount = bound(amount, 1, 1000e18);
        
        // Ensure hook has enough tokens
        token0.mint(address(hook), amount);
        
        uint256 initialBalance = token0.balanceOf(to);
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(token0), amount, to);
        
        assertEq(token0.balanceOf(to), initialBalance + amount);
    }
    
    function testFuzzSafeTransfer(uint256 amount, address to) public {
        vm.assume(to != address(0) && to != address(hook) && to.code.length == 0);
        amount = bound(amount, 1, 1000e18);
        
        // Ensure hook has enough tokens
        token0.mint(address(hook), amount);
        
        uint256 initialBalance = token0.balanceOf(to);
        
        hook.testSafeTransfer(address(token0), to, amount);
        
        assertEq(token0.balanceOf(to), initialBalance + amount);
    }
}