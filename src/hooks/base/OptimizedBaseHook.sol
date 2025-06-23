// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-core/src/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Errors} from "../../utils/Errors.sol";

/// @title Optimized Base Hook with enhanced functionality
abstract contract OptimizedBaseHook is BaseHook, Ownable, ReentrancyGuard {
    
    bool public isHookPaused;
    
    modifier whenNotPaused() {
        if (isHookPaused) {
            revert Errors.EmergencyPauseActive();
        }
        _;
    }
    
    modifier validPoolKey(PoolKey memory key) {
        if (address(key.currency0) == address(0) || address(key.currency1) == address(0)) {
            revert Errors.InvalidPoolKey();
        }
        _;
    }

    constructor(
        IPoolManager _poolManager,
        address initialOwner
    ) BaseHook(_poolManager) Ownable(initialOwner) {}

    /// @notice Get the hook permissions required
    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Pause/unpause the hook
    function pauseHook(bool pause) external onlyOwner {
        isHookPaused = pause;
    }

    /// @notice Check if hook is paused
    function isPaused() external view returns (bool) {
        return isHookPaused;
    }

    /// @notice Emergency function to recover stuck tokens
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        if (to == address(0)) revert Errors.ZeroAddress();
        
        if (token == address(0)) {
            // Withdraw ETH
            (bool success,) = to.call{value: amount}("");
            if (!success) revert Errors.TransferFailed();
        } else {
            // Withdraw ERC20
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert Errors.TransferFailed();
            }
        }
    }

    /// @notice Validate swap parameters
    function _validateSwapParams(IPoolManager.SwapParams memory params) internal pure {
        if (params.amountSpecified == 0) {
            revert Errors.ZeroAmount();
        }
    }

    /// @notice Get current chain ID
    function _getCurrentChainId() internal view returns (uint256) {
        return block.chainid;
    }

    /// @notice Calculate transaction deadline
    function _calculateDeadline(uint256 additionalTime) internal view returns (uint256) {
        return block.timestamp + additionalTime;
    }

    /// @notice Safe token transfer helper
    function _safeTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0) || to == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert Errors.TransferFailed();
        }
    }

    /// @notice Safe token transferFrom helper
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
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

    /// @notice Get token balance
    function _getTokenBalance(address token, address account) internal view returns (uint256) {
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

    receive() external payable {}
}