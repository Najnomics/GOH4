// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";

contract SetupGasPrices is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // GasPriceOracle address from deployment
        GasPriceOracle oracle = GasPriceOracle(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== SETTING UP GAS PRICE ORACLE ===");
        console.log("Oracle address:", address(oracle));

        // Set realistic gas prices for different chains (in gwei)
        uint256[] memory chainIds = new uint256[](7);
        uint256[] memory gasPricesArray = new uint256[](7);
        
        // Ethereum mainnet - typically 15-50 gwei
        chainIds[0] = 1;
        gasPricesArray[0] = 25 * 10**9; // 25 gwei
        console.log("Preparing Ethereum (1) gas price: 25 gwei");

        // Polygon - typically 30-100 gwei  
        chainIds[1] = 137;
        gasPricesArray[1] = 50 * 10**9; // 50 gwei
        console.log("Preparing Polygon (137) gas price: 50 gwei");

        // Arbitrum - typically 0.1-1 gwei
        chainIds[2] = 42161;
        gasPricesArray[2] = 1 * 10**8; // 0.1 gwei
        console.log("Preparing Arbitrum (42161) gas price: 0.1 gwei");

        // Optimism - typically 0.001-0.01 gwei
        chainIds[3] = 10;
        gasPricesArray[3] = 1 * 10**6; // 0.001 gwei
        console.log("Preparing Optimism (10) gas price: 0.001 gwei");

        // Base - typically 0.001-0.01 gwei
        chainIds[4] = 8453;
        gasPricesArray[4] = 5 * 10**6; // 0.005 gwei
        console.log("Preparing Base (8453) gas price: 0.005 gwei");

        // BSC - typically 3-10 gwei
        chainIds[5] = 56;
        gasPricesArray[5] = 5 * 10**9; // 5 gwei
        console.log("Preparing BSC (56) gas price: 5 gwei");

        // Avalanche - typically 25-100 gwei
        chainIds[6] = 43114;
        gasPricesArray[6] = 40 * 10**9; // 40 gwei
        console.log("Preparing Avalanche (43114) gas price: 40 gwei");

        // Update all gas prices at once
        oracle.updateGasPrices(chainIds, gasPricesArray);
        console.log("All gas prices updated successfully!");

        console.log("=== VERIFYING GAS PRICES ===");
        
        // Verify the prices were set correctly
        for (uint i = 0; i < chainIds.length; i++) {
            (uint256 price, uint256 timestamp) = oracle.getGasPrice(chainIds[i]);
            console.log("Chain ID:", chainIds[i]);
            console.log("Gas price:", price / 10**9, "gwei");
            console.log("Timestamp:", timestamp);
            console.log("---");
        }

        vm.stopBroadcast();
    }
} 