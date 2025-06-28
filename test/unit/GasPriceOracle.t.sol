// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract GasPriceOracleTest is Test {
    GasPriceOracle oracle;
    address owner = address(0x1);
    address keeper = address(0x2);
    address user = address(0x3);

    function setUp() public {
        oracle = new GasPriceOracle(owner, keeper);
    }

    function testUpdateGasPrices() public {
        vm.prank(keeper);
        
        uint256[] memory chainIds = new uint256[](2);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](2);
        prices[0] = 20e9; // 20 gwei
        prices[1] = 1e9;  // 1 gwei
        
        oracle.updateGasPrices(chainIds, prices);
        
        (uint256 ethPrice, uint256 ethTimestamp) = oracle.getGasPrice(Constants.ETHEREUM_CHAIN_ID);
        (uint256 arbPrice, uint256 arbTimestamp) = oracle.getGasPrice(Constants.ARBITRUM_CHAIN_ID);
        
        assertEq(ethPrice, 20e9);
        assertEq(arbPrice, 1e9);
        assertGt(ethTimestamp, 0);
        assertGt(arbTimestamp, 0);
    }

    function testOnlyKeeperCanUpdate() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](1);
        prices[0] = 20e9;
        
        vm.prank(user);
        vm.expectRevert(Errors.UnauthorizedKeeper.selector);
        oracle.updateGasPrices(chainIds, prices);
    }

    function testOwnerCanUpdate() public {
        vm.prank(owner);
        
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](1);
        prices[0] = 20e9;
        
        oracle.updateGasPrices(chainIds, prices);
        
        (uint256 price,) = oracle.getGasPrice(Constants.ETHEREUM_CHAIN_ID);
        assertEq(price, 20e9);
    }

    function testInvalidChainId() public {
        vm.prank(keeper);
        
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 999; // Invalid chain ID
        
        uint256[] memory prices = new uint256[](1);
        prices[0] = 20e9;
        
        vm.expectRevert(Errors.InvalidChainId.selector);
        oracle.updateGasPrices(chainIds, prices);
    }

    function testGasPriceTrend() public {
        // Add multiple price updates
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(keeper);
            
            uint256[] memory chainIds = new uint256[](1);
            chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
            
            uint256[] memory prices = new uint256[](1);
            prices[0] = (i + 1) * 10e9; // 10, 20, 30, 40, 50 gwei
            
            oracle.updateGasPrices(chainIds, prices);
        }
        
        GasPriceOracle.GasTrend memory trend = oracle.getGasPriceTrend(Constants.ETHEREUM_CHAIN_ID, 5);
        
        assertEq(trend.minPrice, 10e9);
        assertEq(trend.maxPrice, 50e9);
        assertEq(trend.averagePrice, 30e9);
        assertTrue(trend.isIncreasing);
    }

    function testUpdateKeeper() public {
        address newKeeper = address(0x4);
        
        vm.prank(owner);
        oracle.updateKeeper(newKeeper);
        
        assertEq(oracle.keeper(), newKeeper);
    }

    function testValidateGasPrice() public {
        assertTrue(oracle.validateGasPrice(Constants.ETHEREUM_CHAIN_ID, 20e9));
        assertFalse(oracle.validateGasPrice(999, 20e9)); // Invalid chain
        assertFalse(oracle.validateGasPrice(Constants.ETHEREUM_CHAIN_ID, 0)); // Invalid gas price
    }

    function testGetSupportedChains() public {
        uint256[] memory chains = oracle.getSupportedChains();
        assertEq(chains.length, 5);
        assertEq(chains[0], Constants.ETHEREUM_CHAIN_ID);
        assertEq(chains[1], Constants.ARBITRUM_CHAIN_ID);
    }
}