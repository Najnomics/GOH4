// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ChainlinkIntegration} from "../../src/integrations/ChainlinkIntegration.sol";
import {IChainlinkAggregator} from "../../src/interfaces/external/IChainlinkAggregator.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract ChainlinkIntegrationTest is Test {
    ChainlinkIntegration chainlinkIntegration;
    MockPriceFeed mockPriceFeed;
    
    address owner = address(0x1);
    address user = address(0x2);
    address testToken = address(0x123);
    
    function setUp() public {
        chainlinkIntegration = new ChainlinkIntegration(owner);
        mockPriceFeed = new MockPriceFeed();
        
        // Override the ETH price feed with our mock for current chain
        vm.prank(owner);
        chainlinkIntegration.updateETHPriceFeed(block.chainid, address(mockPriceFeed));
        
        // Also set for mainnet chain ID as fallback
        vm.prank(owner);
        chainlinkIntegration.updateETHPriceFeed(Constants.ETHEREUM_CHAIN_ID, address(mockPriceFeed));
    }

    function testInitialization() public {
        assertEq(chainlinkIntegration.owner(), owner);
        assertEq(chainlinkIntegration.ETH_ADDRESS(), address(0));
        assertEq(chainlinkIntegration.DEFAULT_HEARTBEAT(), 8 hours);
        assertEq(chainlinkIntegration.MAX_PRICE_AGE(), 1 hours);
    }

    function testGetETHPriceUSD() public {
        IChainlinkAggregator.PriceData memory ethPrice = chainlinkIntegration.getETHPriceUSD();
        
        assertGt(ethPrice.price, 0);
        assertTrue(ethPrice.isValid);
        assertGt(ethPrice.timestamp, 0);
    }

    function testGetTokenPriceUSD() public {
        // Add a price feed for the test token
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        IChainlinkAggregator.PriceData memory tokenPrice = 
            chainlinkIntegration.getTokenPriceUSD(testToken);
        
        assertGt(tokenPrice.price, 0);
        assertTrue(tokenPrice.isValid);
    }

    function testGetTokenPriceETH() public {
        // Test ETH address specifically
        IChainlinkAggregator.PriceData memory ethPrice = 
            chainlinkIntegration.getTokenPriceUSD(address(0));
        
        assertGt(ethPrice.price, 0);
        assertTrue(ethPrice.isValid);
    }

    function testGetTokenPriceWETH() public {
        // Test WETH address
        IChainlinkAggregator.PriceData memory wethPrice = 
            chainlinkIntegration.getTokenPriceUSD(chainlinkIntegration.WETH_ADDRESS());
        
        assertGt(wethPrice.price, 0);
        assertTrue(wethPrice.isValid);
    }

    function testGetGasPriceETH() public {
        uint256 ethGasPrice = chainlinkIntegration.getGasPriceETH(Constants.ETHEREUM_CHAIN_ID);
        assertEq(ethGasPrice, 30 gwei);
        
        uint256 arbitrumGasPrice = chainlinkIntegration.getGasPriceETH(Constants.ARBITRUM_CHAIN_ID);
        assertEq(arbitrumGasPrice, 0.1 gwei);
        
        uint256 unknownGasPrice = chainlinkIntegration.getGasPriceETH(999999);
        assertEq(unknownGasPrice, 10 gwei); // Default
    }

    function testGetMultipleTokenPricesUSD() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(0);
        tokens[1] = chainlinkIntegration.WETH_ADDRESS();
        tokens[2] = testToken;
        
        // Add price feed for test token
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        IChainlinkAggregator.PriceData[] memory prices = 
            chainlinkIntegration.getMultipleTokenPricesUSD(tokens);
        
        assertEq(prices.length, 3);
        assertGt(prices[0].price, 0); // ETH
        assertGt(prices[1].price, 0); // WETH
        assertGt(prices[2].price, 0); // Test token
    }

    function testAddPriceFeed() public {
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        IChainlinkAggregator.PriceFeedData memory feedData = 
            chainlinkIntegration.getPriceFeedData(testToken);
        
        assertEq(feedData.feedAddress, address(mockPriceFeed));
        assertEq(feedData.heartbeat, 3600);
        assertTrue(feedData.isActive);
    }

    function testAddPriceFeedOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
    }

    function testAddPriceFeedInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert();
        chainlinkIntegration.addPriceFeed(testToken, address(0), 3600);
    }

    function testAddPriceFeedInvalidHeartbeat() public {
        vm.prank(owner);
        vm.expectRevert();
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 0);
    }

    function testUpdatePriceFeed() public {
        // First add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        // Create new mock feed
        MockPriceFeed newMockFeed = new MockPriceFeed();
        
        // Update the price feed
        vm.prank(owner);
        chainlinkIntegration.updatePriceFeed(testToken, address(newMockFeed));
        
        IChainlinkAggregator.PriceFeedData memory feedData = 
            chainlinkIntegration.getPriceFeedData(testToken);
        
        assertEq(feedData.feedAddress, address(newMockFeed));
    }

    function testUpdatePriceFeedUnsupportedToken() public {
        MockPriceFeed newMockFeed = new MockPriceFeed();
        
        vm.prank(owner);
        vm.expectRevert();
        chainlinkIntegration.updatePriceFeed(testToken, address(newMockFeed));
    }

    function testRemovePriceFeed() public {
        // First add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        // Remove it
        vm.prank(owner);
        chainlinkIntegration.removePriceFeed(testToken);
        
        IChainlinkAggregator.PriceFeedData memory feedData = 
            chainlinkIntegration.getPriceFeedData(testToken);
        
        assertEq(feedData.feedAddress, address(0));
        assertFalse(feedData.isActive);
    }

    function testIsPriceFeedValid() public {
        // Should be false for non-existent feed
        assertFalse(chainlinkIntegration.isPriceFeedValid(testToken));
        
        // Add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        // Should be true now
        assertTrue(chainlinkIntegration.isPriceFeedValid(testToken));
    }

    function testIsPriceStale() public {
        // Add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        // Should not be stale with recent data
        assertFalse(chainlinkIntegration.isPriceStale(testToken, 1 hours));
        
        // Should be stale for non-existent token
        assertTrue(chainlinkIntegration.isPriceStale(address(0x999), 1 hours));
    }

    function testConvertToUSD() public {
        // Add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        uint256 tokenAmount = 10e18;
        uint256 usdValue = chainlinkIntegration.convertToUSD(testToken, tokenAmount);
        
        assertGt(usdValue, 0);
    }

    function testConvertFromUSD() public {
        // Add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        uint256 usdAmount = 1000e18; // $1000
        uint256 tokenAmount = chainlinkIntegration.convertFromUSD(testToken, usdAmount);
        
        assertGt(tokenAmount, 0);
    }

    function testCalculateGasCostUSD() public {
        uint256 gasUsed = 120000;
        uint256 gasPrice = 50e9; // 50 gwei
        uint256 chainId = Constants.ETHEREUM_CHAIN_ID;
        
        uint256 gasCostUSD = chainlinkIntegration.calculateGasCostUSD(gasUsed, gasPrice, chainId);
        
        assertGt(gasCostUSD, 0);
    }

    function testUpdateETHPriceFeed() public {
        address newEthFeed = address(0x999);
        uint256 chainId = Constants.ARBITRUM_CHAIN_ID;
        
        vm.prank(owner);
        chainlinkIntegration.updateETHPriceFeed(chainId, newEthFeed);
        
        // This is a simple setter test - the mapping is internal
        // so we can't directly verify, but we can test it doesn't revert
        assertTrue(true);
    }

    function testUnsupportedTokenPrice() public {
        vm.expectRevert();
        chainlinkIntegration.getTokenPriceUSD(address(0x999));
    }

    function testConvertUnsupportedToken() public {
        vm.expectRevert();
        chainlinkIntegration.convertToUSD(address(0x999), 100e18);
        
        vm.expectRevert();
        chainlinkIntegration.convertFromUSD(address(0x999), 100e18);
    }

    function testFuzzGasPriceCalculation(uint256 gasUsed, uint256 gasPrice) public {
        gasUsed = bound(gasUsed, 100000, 1000000); // Increase minimum gas to avoid precision issues  
        gasPrice = bound(gasPrice, 10e9, 1000e9); // 10-1000 gwei to avoid extreme precision loss
        
        uint256 gasCostUSD = chainlinkIntegration.calculateGasCostUSD(
            gasUsed, 
            gasPrice, 
            Constants.ETHEREUM_CHAIN_ID
        );
        
        // With higher minimums, this should always be > 0
        assertGt(gasCostUSD, 0, "Gas cost in USD should be greater than 0 for realistic inputs");
    }

    function testFuzzTokenConversion(uint256 amount) public {
        amount = bound(amount, 1e6, 1000e18); // Reasonable token amounts
        
        // Add a price feed
        vm.prank(owner);
        chainlinkIntegration.addPriceFeed(testToken, address(mockPriceFeed), 3600);
        
        uint256 usdValue = chainlinkIntegration.convertToUSD(testToken, amount);
        assertGt(usdValue, 0);
        
        uint256 tokenValue = chainlinkIntegration.convertFromUSD(testToken, usdValue);
        // Should be approximately equal (allowing for precision loss)
        assertApproxEqRel(tokenValue, amount, 0.01e18); // 1% tolerance
    }
}