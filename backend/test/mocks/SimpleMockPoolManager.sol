// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title Simple Mock Pool Manager for testing
contract SimpleMockPoolManager {
    function getLiquidity(PoolId) external pure returns (uint128) { 
        return 1000e18; 
    }
    
    function getSlot0(PoolId) external pure returns (uint160, int24, uint24, uint24) {
        return (79228162514264337593543950336, 0, 0, 3000); 
    }
}