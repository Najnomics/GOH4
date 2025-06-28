// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainManager} from "../../src/core/CrossChainManager.sol";
import {ICrossChainManager} from "../../src/interfaces/ICrossChainManager.sol";
import {MockSpokePool} from "../mocks/MockSpokePool.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract CrossChainManagerTest is Test {
    CrossChainManager crossChainManager;
    MockSpokePool mockSpokePool;
    
    address owner = address(0x1);
    address user = address(0x2);
    address tokenA = address(0x3);
    address tokenB = address(0x4);

    function setUp() public {
        mockSpokePool = new MockSpokePool();
        crossChainManager = new CrossChainManager(owner, address(mockSpokePool));
    }

    function testInitiateCrossChainSwap() public {
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
        
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(swapState.user, user);
        assertEq(swapState.tokenIn, tokenA);
        assertEq(swapState.tokenOut, tokenB);
        assertEq(swapState.amountIn, 1e18);
        // The implementation sets status to Bridging instead of Initiated
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Bridging));
        assertTrue(crossChainManager.isSwapActive(swapId));
    }

    function testCompleteSwapFlow() public {
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
        
        // Handle destination swap
        crossChainManager.handleDestinationSwap(swapId, "");
        
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.BridgingBack));
        
        // Complete swap
        crossChainManager.completeCrossChainSwap(swapId);
        
        swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Completed));
        assertFalse(crossChainManager.isSwapActive(swapId));
        assertGt(swapState.completedAt, 0);
        assertGt(swapState.amountOut, 0);
    }

    function testInvalidParameters() public {
        // Zero address user
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: address(0),
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1e18,
            minAmountOut: 0.99e18,
            sourceChainId: Constants.ETHEREUM_CHAIN_ID,
            destinationChainId: Constants.ARBITRUM_CHAIN_ID,
            deadline: block.timestamp + 3600,
            swapData: ""
        });
        
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        crossChainManager.initiateCrossChainSwap(params);
        
        // Zero amount
        params.user = user;
        params.amountIn = 0;
        
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAmount.selector));
        crossChainManager.initiateCrossChainSwap(params);
        
        // Expired deadline
        params.amountIn = 1e18;
        params.deadline = block.timestamp - 1;
        
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidBridgeParams.selector));
        crossChainManager.initiateCrossChainSwap(params);
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
        
        // Try recovery too early (should fail)
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Errors.BridgeTimeout.selector));
        crossChainManager.emergencyRecovery(swapId);
        
        // Fast forward time past timeout
        vm.warp(block.timestamp + 3601);
        
        // Now recovery should work
        vm.prank(user);
        crossChainManager.emergencyRecovery(swapId);
        
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Recovered));
        assertFalse(crossChainManager.isSwapActive(swapId));
    }

    function testOwnerEmergencyRecovery() public {
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
        
        // Fast forward time
        vm.warp(block.timestamp + 3601);
        
        // Owner can recover any swap
        vm.prank(owner);
        crossChainManager.emergencyRecovery(swapId);
        
        CrossChainManager.SwapState memory swapState = crossChainManager.getSwapState(swapId);
        assertEq(uint8(swapState.status), uint8(ICrossChainManager.SwapStatus.Recovered));
    }

    function testUnauthorizedRecovery() public {
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
        
        // Fast forward time
        vm.warp(block.timestamp + 3601);
        
        // Random user cannot recover
        address randomUser = address(0x5);
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedSender.selector));
        crossChainManager.emergencyRecovery(swapId);
    }

    function testPauseOperations() public {
        // Pause operations
        vm.prank(owner);
        crossChainManager.pauseCrossChainOperations(true);
        
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
        
        // Unpause
        vm.prank(owner);
        crossChainManager.pauseCrossChainOperations(false);
        
        // Should work now
        bytes32 swapId = crossChainManager.initiateCrossChainSwap(params);
        assertTrue(crossChainManager.isSwapActive(swapId));
    }

    function testChainConfiguration() public {
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
        
        // Re-enable Arbitrum
        vm.prank(owner);
        crossChainManager.updateChainConfiguration(Constants.ARBITRUM_CHAIN_ID, true, 100e9);
        
        // Should work now
        bytes32 swapId = crossChainManager.initiateCrossChainSwap(params);
        assertTrue(crossChainManager.isSwapActive(swapId));
    }

    function testGetStatistics() public {
        // Initially should be zero
        (uint256 totalSwaps, uint256 successfulSwaps, uint256 failedSwaps, uint256 avgTime) = 
            crossChainManager.getSwapStatistics();
        assertEq(totalSwaps, 0);
        assertEq(successfulSwaps, 0);
        assertEq(failedSwaps, 0);
        assertEq(avgTime, 0);
        
        // Complete a successful swap
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
        
        // Advance time to simulate execution time
        vm.warp(block.timestamp + 300); // 5 minutes
        
        crossChainManager.handleDestinationSwap(swapId, "");
        crossChainManager.completeCrossChainSwap(swapId);
        
        (totalSwaps, successfulSwaps, failedSwaps, avgTime) = crossChainManager.getSwapStatistics();
        assertEq(totalSwaps, 1);
        assertEq(successfulSwaps, 1);
        assertEq(failedSwaps, 0);
        assertEq(avgTime, 300); // 5 minutes
    }

    function testUserActiveSwaps() public {
        address user2 = address(0x6);
        
        // Create swap for user1
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
        
        // Create swap for user2
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
        
        // Check user active swaps
        bytes32[] memory user1Swaps = crossChainManager.getUserActiveSwaps(user);
        bytes32[] memory user2Swaps = crossChainManager.getUserActiveSwaps(user2);
        
        assertEq(user1Swaps.length, 1);
        assertEq(user2Swaps.length, 1);
        assertEq(user1Swaps[0], swapId1);
        assertEq(user2Swaps[0], swapId2);
        
        // Complete user1's swap
        crossChainManager.handleDestinationSwap(swapId1, "");
        crossChainManager.completeCrossChainSwap(swapId1);
        
        // User1 should have no active swaps, user2 should still have 1
        user1Swaps = crossChainManager.getUserActiveSwaps(user);
        user2Swaps = crossChainManager.getUserActiveSwaps(user2);
        
        assertEq(user1Swaps.length, 0);
        assertEq(user2Swaps.length, 1);
    }
}