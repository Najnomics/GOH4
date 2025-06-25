// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";
import {CrossChainManager} from "../../src/core/CrossChainManager.sol";
import {GasOptimizationHook} from "../../src/hooks/GasOptimizationHook.sol";
import {ChainlinkIntegration} from "../../src/integrations/ChainlinkIntegration.sol";
import {AcrossIntegration} from "../../src/integrations/AcrossIntegration.sol";
import {UniswapV4Integration} from "../../src/integrations/UniswapV4Integration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title Main deployment script for Gas Optimization Hook system
contract Deploy is Script {
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Chainlink Integration first
        ChainlinkIntegration chainlinkIntegration = new ChainlinkIntegration(deployer);
        console.log("ChainlinkIntegration deployed to:", address(chainlinkIntegration));
        
        // Deploy Across Integration
        AcrossIntegration acrossIntegration = new AcrossIntegration(deployer);
        console.log("AcrossIntegration deployed to:", address(acrossIntegration));
        
        // Deploy Gas Price Oracle
        GasPriceOracle gasPriceOracle = new GasPriceOracle(
            deployer, // owner
            deployer  // initial keeper
        );
        console.log("GasPriceOracle deployed to:", address(gasPriceOracle));
        
        // Deploy Cost Calculator with Chainlink Integration
        CostCalculator costCalculator = new CostCalculator(
            deployer, // owner
            address(gasPriceOracle),
            address(chainlinkIntegration)
        );
        console.log("CostCalculator deployed to:", address(costCalculator));
        
        // Deploy Cross Chain Manager with Across Integration
        CrossChainManager crossChainManager = new CrossChainManager(
            deployer,
            address(acrossIntegration)
        );
        console.log("CrossChainManager deployed to:", address(crossChainManager));
        
        // Note: For UniswapV4Integration and GasOptimizationHook deployment,
        // we need the actual PoolManager address which varies by network
        console.log("=== Manual deployment required for: ===");
        console.log("- UniswapV4Integration (requires PoolManager address)");
        console.log("- GasOptimizationHook (requires PoolManager address)");
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("ChainlinkIntegration:", address(chainlinkIntegration));
        console.log("AcrossIntegration:", address(acrossIntegration));
        console.log("GasPriceOracle:", address(gasPriceOracle));
        console.log("CostCalculator:", address(costCalculator));
        console.log("CrossChainManager:", address(crossChainManager));
        console.log("Owner:", deployer);
        console.log("Chain ID:", block.chainid);
    }
}