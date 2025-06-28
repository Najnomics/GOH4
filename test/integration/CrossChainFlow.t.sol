// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainManager} from "../../src/core/CrossChainManager.sol";
import {ICrossChainManager} from "../../src/interfaces/ICrossChainManager.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";
import {MockSpokePool} from "../mocks/MockSpokePool.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {MockChainlinkIntegration} from "../mocks/MockChainlinkIntegration.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract CrossChainFlowTest is Test {
    CrossChainManager crossChainManager;
    GasPriceOracle gasPriceOracle;
    CostCalculator costCalculator;
    MockSpokePool mockSpokePool;
    MockPriceFeed mockPriceFeed;
    MockChainlinkIntegration mockChainlink;
    
    address owner = address(0x1);
    address user = address(0x2);
    address tokenA = address(0x3);
    address tokenB = address(0x4);

    function setUp() public {
        mockSpokePool = new MockSpokePool();
        mockPriceFeed = new MockPriceFeed();
        mockChainlink = new MockChainlinkIntegration();
        gasPriceOracle = new GasPriceOracle(owner, owner);
        costCalculator = new CostCalculator(owner, address(gasPriceOracle), address(mockChainlink));
        crossChainManager = new CrossChainManager(owner, address(mockSpokePool));
        
        // Setup mock price feeds for the oracle
        vm.startPrank(owner);
        gasPriceOracle.addChain(Constants.ETHEREUM_CHAIN_ID, address(mockPriceFeed));
        gasPriceOracle.addChain(Constants.ARBITRUM_CHAIN_ID, address(mockPriceFeed));
        vm.stopPrank();
        
        // Setup gas prices
        vm.prank(owner);
        uint256[] memory chainIds = new uint256[](2);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](2);
        prices[0] = 50e9; // Expensive: 50 gwei
        prices[1] = 1e9;  // Cheap: 1 gwei
        
        gasPriceOracle.updateGasPrices(chainIds, prices);
    }

    function testCrossChainSwapFlow() public {
        // Initiate cross-chain swap
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        bytes32 swapId = crossChainManager.initiateCrossChainSwap(params);
        
        // Verify swap state - the implementation sets status to Bridging instead of Initiated
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(swapState.user, user);
        assertEq(swapState.tokenIn, tokenA);
        assertEq(swapState.tokenOut, tokenB);
        assertEq(swapState.amountIn, 1e18);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Bridging));
        
        // Check user active swaps
        bytes32[] memory activeSwaps = crossChainManager.getUserActiveSwaps(user);
        assertEq(activeSwaps.length, 1);
        assertEq(activeSwaps[0], swapId);
        
        // Advance time to simulate execution time
        vm.warp(block.timestamp + 300); // 5 minutes
        
        // Handle destination swap (simulate bridge completion)
        crossChainManager.handleDestinationSwap(swapId, "");
        
        // Complete the swap
        crossChainManager.completeCrossChainSwap(swapId);
        
        // Verify final state
        swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Completed));
        assertGt(swapState.completedAt, 0);
        assertFalse(crossChainManager.isSwapActive(swapId));
        
        // Check statistics
        (uint256 totalSwaps, uint256 successfulSwaps, uint256 failedSwaps, uint256 avgTime) = 
            crossChainManager.getSwapStatistics();
        assertEq(totalSwaps, 1);
        assertEq(successfulSwaps, 1);
        assertEq(failedSwaps, 0);
        assertGt(avgTime, 0);
    }

    function testEmergencyRecovery() public {
        // Initiate swap
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        bytes32 swapId = crossChainManager.initiateCrossChainSwap(params);
        
        // Fast forward time to simulate timeout
        vm.warp(block.timestamp + 3601);
        
        // Emergency recovery should work after timeout
        vm.prank(user);
        crossChainManager.emergencyRecovery(swapId);
        
        // Verify recovered state
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Recovered));
        assertFalse(crossChainManager.isSwapActive(swapId));
    }

    function testPauseOperations() public {
        // Pause operations
        vm.prank(owner);
        crossChainManager.pauseCrossChainOperations(true);
        
        // Should revert when paused
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        vm.expectRevert(abi.encodeWithSelector(Errors.EmergencyPauseActive.selector));
        crossChainManager.initiateCrossChainSwap(params);
    }

    function testInvalidChain() public {
        // Disable Arbitrum
        vm.prank(owner);
        crossChainManager.updateChainConfiguration(Constants.ARBITRUM_CHAIN_ID, false, 0);
        
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidDestinationChain.selector));
        crossChainManager.initiateCrossChainSwap(params);
    }

    function testMultipleUserSwaps() public {
        address user2 = address(0x5);
        
        // User 1 swap
        ICrossChainManager.CrossChainSwapParams memory params1 = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        // User 2 swap
        ICrossChainManager.CrossChainSwapParams memory params2 = ICrossChainManager.CrossChainSwapParams({
            user: user2,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 2e18,
            minAmountOut: 1.98e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.OPTIMISM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        bytes32 swapId1 = crossChainManager.initiateCrossChainSwap(params1);
        bytes32 swapId2 = crossChainManager.initiateCrossChainSwap(params2);
        
        // Check each user has their own active swaps
        bytes32[] memory user1Swaps = crossChainManager.getUserActiveSwaps(user);
        bytes32[] memory user2Swaps = crossChainManager.getUserActiveSwaps(user2);
        
        assertEq(user1Swaps.length, 1);
        assertEq(user2Swaps.length, 1);
        assertEq(user1Swaps[0], swapId1);
        assertEq(user2Swaps[0], swapId2);
    }
}