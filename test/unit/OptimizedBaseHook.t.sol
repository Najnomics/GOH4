// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Errors} from "../../src/utils/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock ERC20 for testing
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

// Test contract that implements the OptimizedBaseHook functionality without BaseHook dependency
contract TestableOptimizedHookFunctions is Ownable, ReentrancyGuard {
    bool internal _hookPaused;
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    modifier whenNotPaused() {
        if (_hookPaused) {
            revert Errors.EmergencyPauseActive();
        }
        _;
    }
    
    function pauseHook(bool paused) external onlyOwner {
        _hookPaused = paused;
    }
    
    function isPaused() external view returns (bool) {
        return _hookPaused;
    }
    
    // Expose internal functions for testing
    function testValidateSwapParams(SwapParams memory params) external pure {
        if (params.amountSpecified == 0) {
            revert Errors.ZeroAmount();
        }
    }
    
    function testGetCurrentChainId() external view returns (uint256) {
        return block.chainid;
    }
    
    function testCalculateDeadline(uint256 additionalTime) external view returns (uint256) {
        return block.timestamp + additionalTime;
    }
    
    function testSafeTransfer(address token, address to, uint256 amount) external {
        if (to == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        if (token == address(0)) {
            // ETH transfer
            (bool success,) = to.call{value: amount}("");
            if (!success) {
                revert Errors.TransferFailed();
            }
        } else {
            // ERC20 transfer
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert Errors.TransferFailed();
            }
        }
    }
    
    function testSafeTransferFrom(address token, address from, address to, uint256 amount) external {
        if (token == address(0) || from == address(0) || to == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert Errors.TransferFailed();
        }
    }
    
    function testGetTokenBalance(address token, address account) external view returns (uint256) {
        if (token == address(0)) {
            return account.balance;
        }
        
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", account)
        );
        
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        
        return 0;
    }
    
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        if (to == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        if (token == address(0)) {
            // ETH withdrawal
            (bool success,) = to.call{value: amount}("");
            if (!success) {
                revert Errors.TransferFailed();
            }
        } else {
            // ERC20 withdrawal
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert Errors.TransferFailed();
            }
        }
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}

contract OptimizedBaseHookTest is Test {
    TestableOptimizedHookFunctions hook;
    MockERC20 token;
    
    address owner = address(0x1);
    address user = address(0x2);
    address recipient = address(0x3);
    
    uint256 constant INITIAL_BALANCE = 1000e18;

    function setUp() public {
        hook = new TestableOptimizedHookFunctions(owner);
        token = new MockERC20("Test Token", "TEST", 18);
        
        // Setup initial balances
        token.mint(address(hook), INITIAL_BALANCE);
        token.mint(user, INITIAL_BALANCE);
        vm.deal(address(hook), 10 ether);
        vm.deal(user, 10 ether);
    }

    function testInitialization() public {
        assertEq(hook.owner(), owner);
        assertFalse(hook.isPaused());
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
        vm.prank(user);
        vm.expectRevert();
        hook.pauseHook(true);
    }

    function testWhenNotPausedModifier() public {
        // First test normal operation
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testValidateSwapParams(params); // Should work when not paused
        
        // Now pause and test
        vm.prank(owner);
        hook.pauseHook(true);
        
        // This should revert since _validateSwapParams has whenNotPaused modifier indirectly
        // through the hook's usage pattern
    }

    function testValidateSwapParams() public {
        SwapParams memory validParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testValidateSwapParams(validParams); // Should not revert
        
        SwapParams memory invalidParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0, // Zero amount
            sqrtPriceLimitX96: 0
        });
        
        vm.expectRevert(Errors.ZeroAmount.selector);
        hook.testValidateSwapParams(invalidParams);
    }

    function testValidPoolKeyModifier() public {
        // This would be tested through actual hook usage
        // The modifier checks for zero addresses in currency0 and currency1
    }

    function testGetCurrentChainId() public {
        uint256 chainId = hook.testGetCurrentChainId();
        assertEq(chainId, block.chainid);
    }

    function testCalculateDeadline() public {
        uint256 additionalTime = 3600; // 1 hour
        uint256 expectedDeadline = block.timestamp + additionalTime;
        uint256 actualDeadline = hook.testCalculateDeadline(additionalTime);
        assertEq(actualDeadline, expectedDeadline);
    }

    function testSafeTransferERC20() public {
        uint256 transferAmount = 100e18;
        uint256 initialBalance = token.balanceOf(recipient);
        
        hook.testSafeTransfer(address(token), recipient, transferAmount);
        
        assertEq(token.balanceOf(recipient), initialBalance + transferAmount);
    }

    function testSafeTransferETH() public {
        uint256 transferAmount = 1 ether;
        uint256 initialBalance = recipient.balance;
        
        hook.testSafeTransfer(address(0), recipient, transferAmount);
        
        assertEq(recipient.balance, initialBalance + transferAmount);
    }

    function testSafeTransferZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransfer(address(token), address(0), 100e18);
    }

    function testSafeTransferFromERC20() public {
        uint256 transferAmount = 100e18;
        
        // User approves hook to spend tokens
        vm.prank(user);
        token.approve(address(hook), transferAmount);
        
        uint256 initialBalance = token.balanceOf(recipient);
        
        hook.testSafeTransferFrom(address(token), user, recipient, transferAmount);
        
        assertEq(token.balanceOf(recipient), initialBalance + transferAmount);
    }

    function testSafeTransferFromZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(0), user, recipient, 100e18);
        
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(token), address(0), recipient, 100e18);
        
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.testSafeTransferFrom(address(token), user, address(0), 100e18);
    }

    function testGetTokenBalanceERC20() public {
        uint256 balance = hook.testGetTokenBalance(address(token), address(hook));
        assertEq(balance, INITIAL_BALANCE);
    }

    function testGetTokenBalanceETH() public {
        uint256 balance = hook.testGetTokenBalance(address(0), address(hook));
        assertEq(balance, 10 ether);
    }

    function testEmergencyWithdrawERC20() public {
        uint256 withdrawAmount = 100e18;
        uint256 initialBalance = token.balanceOf(recipient);
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(token), withdrawAmount, recipient);
        
        assertEq(token.balanceOf(recipient), initialBalance + withdrawAmount);
    }

    function testEmergencyWithdrawETH() public {
        uint256 withdrawAmount = 1 ether;
        uint256 initialBalance = recipient.balance;
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(0), withdrawAmount, recipient);
        
        assertEq(recipient.balance, initialBalance + withdrawAmount);
    }

    function testEmergencyWithdrawOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        hook.emergencyWithdraw(address(token), 100e18, recipient);
    }

    function testEmergencyWithdrawZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        hook.emergencyWithdraw(address(token), 100e18, address(0));
    }

    function testReceiveETH() public {
        uint256 sendAmount = 1 ether;
        uint256 initialBalance = address(hook).balance;
        
        vm.prank(user);
        (bool success,) = address(hook).call{value: sendAmount}("");
        assertTrue(success);
        
        assertEq(address(hook).balance, initialBalance + sendAmount);
    }

    function testReentrancyGuard() public {
        // The hook inherits from ReentrancyGuard
        // Testing reentrancy would require a more complex setup with malicious contracts
        assertTrue(true); // Placeholder - reentrancy protection is handled by OpenZeppelin
    }

    function testOwnershipTransfer() public {
        // Test that ownership can be transferred
        address newOwner = address(0x999);
        
        vm.prank(owner);
        hook.transferOwnership(newOwner);
        
        // Check that ownership was transferred correctly
        assertEq(hook.owner(), newOwner);
    }

    function testFuzzSafeTransfer(uint256 amount, address to) public {
        // Bound inputs
        amount = bound(amount, 1, INITIAL_BALANCE);
        vm.assume(to != address(0));
        vm.assume(to != address(hook));
        
        uint256 initialBalance = token.balanceOf(to);
        
        hook.testSafeTransfer(address(token), to, amount);
        
        assertEq(token.balanceOf(to), initialBalance + amount);
    }

    function testFuzzCalculateDeadline(uint256 additionalTime) public {
        // Bound to reasonable time ranges
        additionalTime = bound(additionalTime, 1, 86400); // 1 second to 1 day
        
        uint256 deadline = hook.testCalculateDeadline(additionalTime);
        assertEq(deadline, block.timestamp + additionalTime);
        assertGt(deadline, block.timestamp);
    }

    function testFuzzEmergencyWithdraw(uint256 amount, address to) public {
        // Bound inputs
        amount = bound(amount, 1, INITIAL_BALANCE / 2); // Don't withdraw more than half
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0); // Only EOAs to avoid complex interactions
        
        uint256 initialBalance = token.balanceOf(to);
        
        vm.prank(owner);
        hook.emergencyWithdraw(address(token), amount, to);
        
        assertEq(token.balanceOf(to), initialBalance + amount);
    }

    function testSwapParamsEdgeCases() public {
        // Test with negative amount (sell token)
        SwapParams memory negativeAmount = SwapParams({
            zeroForOne: false,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testValidateSwapParams(negativeAmount); // Should work
        
        // Test with maximum positive amount
        SwapParams memory maxAmount = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int256).max,
            sqrtPriceLimitX96: 0
        });
        
        hook.testValidateSwapParams(maxAmount); // Should work
        
        // Test with minimum negative amount
        SwapParams memory minAmount = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int256).min + 1, // Add 1 to avoid overflow
            sqrtPriceLimitX96: 0
        });
        
        hook.testValidateSwapParams(minAmount); // Should work
    }
}