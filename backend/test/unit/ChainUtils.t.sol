// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ChainUtils} from "../../src/libraries/ChainUtils.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

// Helper contract to test library functions with expectRevert
contract ChainUtilsWrapper {
    function validateChainId(uint256 chainId) external pure {
        ChainUtils.validateChainId(chainId);
    }
}

contract ChainUtilsTest is Test {
    using ChainUtils for uint256;

    ChainUtilsWrapper wrapper;

    function testGetChainName() public pure {
        assertEq(Constants.ETHEREUM_CHAIN_ID.getChainName(), "Ethereum");
        assertEq(Constants.ARBITRUM_CHAIN_ID.getChainName(), "Arbitrum");
        assertEq(Constants.OPTIMISM_CHAIN_ID.getChainName(), "Optimism");
        assertEq(Constants.POLYGON_CHAIN_ID.getChainName(), "Polygon");
        assertEq(Constants.BASE_CHAIN_ID.getChainName(), "Base");
        assertEq(uint256(999).getChainName(), "Unknown");
    }

    function testIsSupportedChain() public pure {
        assertTrue(Constants.ETHEREUM_CHAIN_ID.isSupportedChain());
        assertTrue(Constants.ARBITRUM_CHAIN_ID.isSupportedChain());
        assertTrue(Constants.OPTIMISM_CHAIN_ID.isSupportedChain());
        assertTrue(Constants.POLYGON_CHAIN_ID.isSupportedChain());
        assertTrue(Constants.BASE_CHAIN_ID.isSupportedChain());
        assertFalse(uint256(999).isSupportedChain());
    }

    function testGetSupportedChains() public pure {
        uint256[] memory chains = ChainUtils.getSupportedChains();
        assertEq(chains.length, 5);
        assertEq(chains[0], Constants.ETHEREUM_CHAIN_ID);
        assertEq(chains[1], Constants.ARBITRUM_CHAIN_ID);
        assertEq(chains[2], Constants.OPTIMISM_CHAIN_ID);
        assertEq(chains[3], Constants.POLYGON_CHAIN_ID);
        assertEq(chains[4], Constants.BASE_CHAIN_ID);
    }

    function setUp() public {
        wrapper = new ChainUtilsWrapper();
    }

    function testValidateChainId() public {
        // Should not revert for valid chains
        wrapper.validateChainId(Constants.ETHEREUM_CHAIN_ID);
        wrapper.validateChainId(Constants.ARBITRUM_CHAIN_ID);
        
        // Should revert for invalid chain
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidChainId.selector));
        wrapper.validateChainId(999);
    }

    function testGetBlockTime() public pure {
        assertEq(Constants.ETHEREUM_CHAIN_ID.getBlockTime(), 12);
        assertEq(Constants.ARBITRUM_CHAIN_ID.getBlockTime(), 1);
        assertEq(Constants.OPTIMISM_CHAIN_ID.getBlockTime(), 2);
        assertEq(Constants.POLYGON_CHAIN_ID.getBlockTime(), 2);
        assertEq(Constants.BASE_CHAIN_ID.getBlockTime(), 2);
    }

    function testGetFinalityTime() public pure {
        assertEq(Constants.ETHEREUM_CHAIN_ID.getFinalityTime(), 780);
        assertEq(Constants.ARBITRUM_CHAIN_ID.getFinalityTime(), 1200);
        assertEq(Constants.OPTIMISM_CHAIN_ID.getFinalityTime(), 1200);
        assertEq(Constants.POLYGON_CHAIN_ID.getFinalityTime(), 256);
        assertEq(Constants.BASE_CHAIN_ID.getFinalityTime(), 1200);
    }

    function testIsLayer2() public pure {
        assertFalse(Constants.ETHEREUM_CHAIN_ID.isLayer2());
        assertTrue(Constants.ARBITRUM_CHAIN_ID.isLayer2());
        assertTrue(Constants.OPTIMISM_CHAIN_ID.isLayer2());
        assertFalse(Constants.POLYGON_CHAIN_ID.isLayer2()); // Polygon is a sidechain
        assertTrue(Constants.BASE_CHAIN_ID.isLayer2());
    }

    function testGetBridgeTime() public pure {
        // Same chain
        assertEq(ChainUtils.getBridgeTime(Constants.ETHEREUM_CHAIN_ID, Constants.ETHEREUM_CHAIN_ID), 0);
        
        // Ethereum to L2
        assertEq(ChainUtils.getBridgeTime(Constants.ETHEREUM_CHAIN_ID, Constants.ARBITRUM_CHAIN_ID), 300);
        
        // L2 to Ethereum
        assertEq(ChainUtils.getBridgeTime(Constants.ARBITRUM_CHAIN_ID, Constants.ETHEREUM_CHAIN_ID), 300);
        
        // L2 to L2
        assertEq(ChainUtils.getBridgeTime(Constants.ARBITRUM_CHAIN_ID, Constants.OPTIMISM_CHAIN_ID), 600);
    }

    function testGetCongestionMultiplier() public pure {
        // Ethereum with low gas price
        assertEq(ChainUtils.getCongestionMultiplier(15e9, Constants.ETHEREUM_CHAIN_ID), 100); // No congestion
        
        // Ethereum with medium gas price
        assertEq(ChainUtils.getCongestionMultiplier(50e9, Constants.ETHEREUM_CHAIN_ID), 150); // Medium congestion
        
        // Ethereum with high gas price
        assertEq(ChainUtils.getCongestionMultiplier(200e9, Constants.ETHEREUM_CHAIN_ID), 200); // High congestion
        
        // Arbitrum with low gas price
        assertEq(ChainUtils.getCongestionMultiplier(0.5e9, Constants.ARBITRUM_CHAIN_ID), 100); // No congestion
    }
}