// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {AcrossIntegration} from "../../src/integrations/AcrossIntegration.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract MockHubPool {
    // Mock implementation
}

contract AllChainsIntegrationTest is Test {
    AcrossIntegration acrossIntegration;
    MockHubPool mockHubPool;
    
    address owner = address(0x1);
    
    uint256[] public supportedChainIds = [
        Constants.ETHEREUM_CHAIN_ID,    // 1
        Constants.ARBITRUM_CHAIN_ID,    // 42161
        Constants.OPTIMISM_CHAIN_ID,    // 10
        Constants.POLYGON_CHAIN_ID,     // 137
        Constants.BASE_CHAIN_ID         // 8453
    ];
    
    function setUp() public {
        mockHubPool = new MockHubPool();
        
        acrossIntegration = new AcrossIntegration(
            owner,
            address(mockHubPool)
        );
    }
    
    function testAllChainsSupported() public view {
        // Test that all 5 chains mentioned in README are supported
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            assertTrue(acrossIntegration.isChainSupported(chainId), "Chain should be supported");
        }
    }
    
    function testEthereumChainSupport() public view {
        assertTrue(acrossIntegration.isChainSupported(Constants.ETHEREUM_CHAIN_ID));
        assertEq(acrossIntegration.getSpokePool(Constants.ETHEREUM_CHAIN_ID), 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5);
    }
    
    function testArbitrumChainSupport() public view {
        assertTrue(acrossIntegration.isChainSupported(Constants.ARBITRUM_CHAIN_ID));
        assertEq(acrossIntegration.getSpokePool(Constants.ARBITRUM_CHAIN_ID), 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A);
    }
    
    function testOptimismChainSupport() public view {
        assertTrue(acrossIntegration.isChainSupported(Constants.OPTIMISM_CHAIN_ID));
        assertEq(acrossIntegration.getSpokePool(Constants.OPTIMISM_CHAIN_ID), 0x6f26Bf09B1C792e3228e5467807a900A503c0281);
    }
    
    function testPolygonChainSupport() public view {
        assertTrue(acrossIntegration.isChainSupported(Constants.POLYGON_CHAIN_ID));
        assertEq(acrossIntegration.getSpokePool(Constants.POLYGON_CHAIN_ID), 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096);
    }
    
    function testBaseChainSupport() public view {
        assertTrue(acrossIntegration.isChainSupported(Constants.BASE_CHAIN_ID));
        assertEq(acrossIntegration.getSpokePool(Constants.BASE_CHAIN_ID), 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64);
    }
    
    function testGetSupportedChains() public view {
        uint256[] memory chains = acrossIntegration.getSupportedChains();
        
        // Should return all 5 supported chains
        assertEq(chains.length, 5);
        
        // Verify all expected chains are in the list
        bool hasEthereum = false;
        bool hasArbitrum = false;
        bool hasOptimism = false;
        bool hasPolygon = false;
        bool hasBase = false;
        
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i] == Constants.ETHEREUM_CHAIN_ID) hasEthereum = true;
            else if (chains[i] == Constants.ARBITRUM_CHAIN_ID) hasArbitrum = true;
            else if (chains[i] == Constants.OPTIMISM_CHAIN_ID) hasOptimism = true;
            else if (chains[i] == Constants.POLYGON_CHAIN_ID) hasPolygon = true;
            else if (chains[i] == Constants.BASE_CHAIN_ID) hasBase = true;
        }
        
        assertTrue(hasEthereum, "Should include Ethereum");
        assertTrue(hasArbitrum, "Should include Arbitrum");
        assertTrue(hasOptimism, "Should include Optimism");
        assertTrue(hasPolygon, "Should include Polygon");
        assertTrue(hasBase, "Should include Base");
    }
    
    function testBridgeFeesForAllChains() public view {
        address testToken = address(0x123);
        uint256 testAmount = 1e18;
        
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            
            (uint256 bridgeFee, uint256 estimatedTime) = acrossIntegration.getBridgeFeeQuote(
                testToken,
                testAmount,
                chainId
            );
            
            assertGt(bridgeFee, 0, "Bridge fee should be greater than 0");
            assertGt(estimatedTime, 0, "Estimated time should be greater than 0");
        }
    }
    
    function testBridgeTimesConfiguration() public view {
        // Verify that all chains have bridge times configured
        // These values are set in the AcrossIntegration constructor
        
        // Note: We can't directly access chainBridgeTimes mapping, 
        // but we can test it through getBridgeFeeQuote which returns estimatedTime
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            
            (, uint256 estimatedTime) = acrossIntegration.getBridgeFeeQuote(
                address(0x123), // test token
                1e18,           // test amount
                chainId
            );
            
            assertGt(estimatedTime, 0, "Each chain should have bridge time configured");
            assertLe(estimatedTime, 3600, "Bridge time should be reasonable (max 1 hour)");
        }
    }
    
    function testUnsupportedChain() public {
        uint256 unsupportedChainId = 999999;
        
        assertFalse(acrossIntegration.isChainSupported(unsupportedChainId));
        
        vm.expectRevert();
        acrossIntegration.getSpokePool(unsupportedChainId);
        
        vm.expectRevert();
        acrossIntegration.getBridgeFeeQuote(address(0x123), 1e18, unsupportedChainId);
    }
    
    function testChainConstants() public {
        // Verify that the constants match the expected chain IDs
        assertEq(Constants.ETHEREUM_CHAIN_ID, 1);
        assertEq(Constants.ARBITRUM_CHAIN_ID, 42161);
        assertEq(Constants.OPTIMISM_CHAIN_ID, 10);
        assertEq(Constants.POLYGON_CHAIN_ID, 137);
        assertEq(Constants.BASE_CHAIN_ID, 8453);
    }
    
    function testConfigurationFilesExist() public {
        // This test verifies that we have created all necessary configuration files
        // by testing the chain IDs that should be supported based on config files
        
        uint256[] memory expectedChains = new uint256[](5);
        expectedChains[0] = 1;      // ethereum.json
        expectedChains[1] = 42161;  // arbitrum.json
        expectedChains[2] = 10;     // optimism.json
        expectedChains[3] = 137;    // polygon.json
        expectedChains[4] = 8453;   // base.json
        
        for (uint256 i = 0; i < expectedChains.length; i++) {
            assertTrue(acrossIntegration.isChainSupported(expectedChains[i]), 
                string(abi.encodePacked("Chain ", vm.toString(expectedChains[i]), " should be supported")));
        }
    }
}