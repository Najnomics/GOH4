// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract MainnetForkTest is Test {
    GasPriceOracle gasPriceOracle;
    CostCalculator costCalculator;
    
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    address owner = address(0x1);
    address keeper = address(0x2);

    function setUp() public {
        // Fork mainnet at recent block
        string memory rpcUrl = vm.envOr("ETHEREUM_RPC_URL", string(""));
        if (bytes(rpcUrl).length > 0) {
            vm.createFork(rpcUrl);
        } else {
            // Skip fork tests if no RPC URL provided
            vm.skip(true);
        }
        
        gasPriceOracle = new GasPriceOracle(owner, keeper);
        costCalculator = new CostCalculator(owner, address(gasPriceOracle));
    }

    function testRealChainlinkPriceFeeds() public {
        // Test with real Chainlink price feeds
        vm.prank(owner);
        gasPriceOracle.addChain(Constants.ETHEREUM_CHAIN_ID, ETH_USD_FEED);
        
        // Update gas price
        vm.prank(keeper);
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](1);
        prices[0] = 20e9; // 20 gwei
        
        gasPriceOracle.updateGasPrices(chainIds, prices);
        
        // Get USD gas price (should work with real price feed)
        uint256 gasPriceUSD = gasPriceOracle.getGasPriceUSD(Constants.ETHEREUM_CHAIN_ID);
        assertGt(gasPriceUSD, 0);
        
        console.log("Gas price in USD (18 decimals):", gasPriceUSD);
    }

    function testCostCalculationWithRealPrices() public {
        if (bytes(vm.envOr("ETHEREUM_RPC_URL", string(""))).length == 0) {
            vm.skip(true);
        }
        
        // Setup with real price feeds
        vm.prank(owner);
        gasPriceOracle.addChain(Constants.ETHEREUM_CHAIN_ID, ETH_USD_FEED);
        
        vm.prank(owner);
        costCalculator.updateTokenPriceFeed(WETH, ETH_USD_FEED);
        
        // Update gas prices
        vm.prank(keeper);
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        uint256[] memory prices = new uint256[](1);
        prices[0] = 30e9; // 30 gwei
        gasPriceOracle.updateGasPrices(chainIds, prices);
        
        // Calculate gas cost
        uint256 gasCostUSD = costCalculator.calculateGasCostUSD(Constants.ETHEREUM_CHAIN_ID, 120000);
        assertGt(gasCostUSD, 0);
        
        console.log("Gas cost for 120k gas in USD:", gasCostUSD);
        
        // Convert 1 ETH to USD
        uint256 ethValueUSD = costCalculator.convertToUSD(WETH, 1e18);
        assertGt(ethValueUSD, 0);
        
        console.log("1 ETH in USD:", ethValueUSD);
    }

    function testGasPriceTrendAnalysis() public {
        vm.prank(keeper);
        
        // Simulate historical gas price data
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        
        // Add multiple price points to build history
        for (uint256 i = 1; i <= 10; i++) {
            uint256[] memory prices = new uint256[](1);
            prices[0] = i * 5e9; // 5, 10, 15... 50 gwei
            
            gasPriceOracle.updateGasPrices(chainIds, prices);
            
            // Advance time between updates
            vm.warp(block.timestamp + 300); // 5 minutes
        }
        
        // Get trend analysis
        GasPriceOracle.GasTrend memory trend = gasPriceOracle.getGasPriceTrend(Constants.ETHEREUM_CHAIN_ID, 10);
        
        assertEq(trend.minPrice, 5e9);
        assertEq(trend.maxPrice, 50e9);
        assertEq(trend.averagePrice, 27.5e9); // Average of 5 to 50
        assertTrue(trend.isIncreasing);
        assertGt(trend.volatility, 0);
        
        console.log("Gas price trend analysis:");
        console.log("Min:", trend.minPrice);
        console.log("Max:", trend.maxPrice);
        console.log("Average:", trend.averagePrice);
        console.log("Volatility (BPS):", trend.volatility);
    }

    function testMultiChainCostComparison() public {
        // Setup multiple chains with different gas prices
        vm.prank(keeper);
        
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        chainIds[2] = Constants.POLYGON_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](3);
        prices[0] = 100e9; // Expensive: 100 gwei
        prices[1] = 0.5e9; // Cheap: 0.5 gwei
        prices[2] = 50e9;  // Medium: 50 gwei
        
        gasPriceOracle.updateGasPrices(chainIds, prices);
        
        // Compare costs across chains
        uint256 gasLimit = 120000;
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (costCalculator.isCostCalculationReliable(chainIds[i])) {
                uint256 gasCostUSD = costCalculator.calculateGasCostUSD(chainIds[i], gasLimit);
                console.log("Chain", chainIds[i], "gas cost USD:", gasCostUSD);
            }
        }
    }
}