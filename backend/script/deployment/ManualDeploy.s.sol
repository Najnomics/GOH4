// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV4Integration} from "../../src/integrations/UniswapV4Integration.sol";
import {GasOptimizationHook} from "../../src/hooks/GasOptimizationHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract ManualDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        address poolManager = vm.envAddress("POOL_MANAGER");
        address positionManager = vm.envAddress("POSITION_MANAGER");
        address router = vm.envAddress("ROUTER");
        address costCalculator = vm.envAddress("COST_CALCULATOR");
        address crossChainManager = vm.envAddress("CROSS_CHAIN_MANAGER");
        address acrossIntegration = vm.envAddress("ACROSS_INTEGRATION");
        address chainlinkIntegration = vm.envAddress("CHAINLINK_INTEGRATION");

        vm.startBroadcast(deployerPrivateKey);

        UniswapV4Integration uni = new UniswapV4Integration(
            IPoolManager(poolManager), positionManager, router, owner
        );
        console.log("UniswapV4Integration deployed to:", address(uni));

        GasOptimizationHook hook = new GasOptimizationHook(
            IPoolManager(poolManager), owner, costCalculator, crossChainManager, acrossIntegration, chainlinkIntegration
        );
        console.log("GasOptimizationHook deployed to:", address(hook));

        vm.stopBroadcast();
    }
}