// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "../../lib/v4-periphery/src/utils/HookMiner.sol";
import {GasOptimizationHook} from "../../src/hooks/GasOptimizationHook.sol";

contract DeployGasOptimizationHookScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        IPoolManager poolManager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address initialOwner = vm.envAddress("OWNER");
        address costCalculator = vm.envAddress("COST_CALCULATOR");
        address crossChainManager = vm.envAddress("CROSS_CHAIN_MANAGER");
        address acrossIntegration = vm.envAddress("ACROSS_INTEGRATION");
        address chainlinkIntegration = vm.envAddress("CHAINLINK_INTEGRATION");

        // Use the permissions required by GasOptimizationHook
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory constructorArgs = abi.encode(
            poolManager,
            initialOwner,
            costCalculator,
            crossChainManager,
            acrossIntegration,
            chainlinkIntegration
        );

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(GasOptimizationHook).creationCode, constructorArgs);

        vm.startBroadcast(deployerPrivateKey);
        GasOptimizationHook hook = new GasOptimizationHook{salt: salt}(
            poolManager,
            initialOwner,
            costCalculator,
            crossChainManager,
            acrossIntegration,
            chainlinkIntegration
        );
        require(address(hook) == hookAddress, "Hook address mismatch");
        console.log("GasOptimizationHook deployed to:", address(hook));
        vm.stopBroadcast();
    }
} 