// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";

/// @title Main deployment script for Gas Optimization Hook system
contract Deploy is Script {
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Gas Price Oracle
        GasPriceOracle gasPriceOracle = new GasPriceOracle(
            deployer, // owner
            deployer  // initial keeper
        );
        
        console.log("GasPriceOracle deployed to:", address(gasPriceOracle));
        
        // Deploy Cost Calculator
        CostCalculator costCalculator = new CostCalculator(
            deployer, // owner
            address(gasPriceOracle)
        );
        
        console.log("CostCalculator deployed to:", address(costCalculator));
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("GasPriceOracle:", address(gasPriceOracle));
        console.log("CostCalculator:", address(costCalculator));
        console.log("Owner:", deployer);
        console.log("Chain ID:", block.chainid);
    }
}