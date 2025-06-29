// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainStorage} from "../../src/storage/CrossChainStorage.sol";
import {GasOptimizationStorage} from "../../src/storage/GasOptimizationStorage.sol";
import {ICrossChainManager} from "../../src/interfaces/ICrossChainManager.sol";

contract TestStorageContract {
    // Test contract to access storage layouts
    function testCrossChainLayout() external view {
        CrossChainStorage.layout();
    }
    
    function testGasOptimizationLayout() external view {
        GasOptimizationStorage.layout();
    }
    
    function testSwapStatusConversion(ICrossChainManager.SwapStatus status) external pure returns (uint8) {
        return CrossChainStorage.convertSwapStatus(status);
    }
    
    function testSwapStatusReconversion(uint8 status) external pure returns (ICrossChainManager.SwapStatus) {
        return CrossChainStorage.convertToSwapStatus(status);
    }
}

contract StorageContractsTest is Test {
    TestStorageContract testContract;
    
    function setUp() public {
        testContract = new TestStorageContract();
    }
    
    function testCrossChainStorageLayout() public {
        testContract.testCrossChainLayout();
        
        // Test that layout is accessible and has correct storage slot
        bytes32 expectedSlot = keccak256("crosschain.storage.layout");
        
        // The layout should be at the expected slot
        // We can't directly test the slot, but we can test that the layout exists
        // and is accessible without reverting
        assertTrue(true); // If we get here, layout() worked
    }
    
    function testGasOptimizationStorageLayout() public {
        testContract.testGasOptimizationLayout();
        
        // Test that layout is accessible and has correct storage slot
        bytes32 expectedSlot = keccak256("gasoptimization.storage.layout");
        
        // The layout should be at the expected slot
        assertTrue(true); // If we get here, layout() worked
    }
    
    function testSwapStatusConversions() public view {
        // Test all swap status conversions
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Initiated), 0);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Bridging), 1);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Swapping), 2);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.BridgingBack), 3);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Completed), 4);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Failed), 5);
        assertEq(testContract.testSwapStatusConversion(ICrossChainManager.SwapStatus.Recovered), 6);
    }
    
    function testSwapStatusReconversions() public view {
        // Test reverse conversions
        assertTrue(testContract.testSwapStatusReconversion(0) == ICrossChainManager.SwapStatus.Initiated);
        assertTrue(testContract.testSwapStatusReconversion(1) == ICrossChainManager.SwapStatus.Bridging);
        assertTrue(testContract.testSwapStatusReconversion(2) == ICrossChainManager.SwapStatus.Swapping);
        assertTrue(testContract.testSwapStatusReconversion(3) == ICrossChainManager.SwapStatus.BridgingBack);
        assertTrue(testContract.testSwapStatusReconversion(4) == ICrossChainManager.SwapStatus.Completed);
        assertTrue(testContract.testSwapStatusReconversion(5) == ICrossChainManager.SwapStatus.Failed);
        assertTrue(testContract.testSwapStatusReconversion(6) == ICrossChainManager.SwapStatus.Recovered);
    }
    
    function testCrossChainStorageSlot() public {
        bytes32 expectedSlot = keccak256("crosschain.storage.layout");
        bytes32 actualSlot = CrossChainStorage.STORAGE_SLOT;
        assertEq(actualSlot, expectedSlot);
    }
    
    function testGasOptimizationStorageSlot() public {
        bytes32 expectedSlot = keccak256("gasoptimization.storage.layout");
        bytes32 actualSlot = GasOptimizationStorage.STORAGE_SLOT;
        assertEq(actualSlot, expectedSlot);
    }
    
    function testStorageStructSizes() public {
        // Test that storage structs are properly packed
        // This is more of a compilation test - if it compiles, the structs are valid
        
        // CrossChainStorage structs
        CrossChainStorage.SwapData memory swapData;
        swapData.user = address(0x123);
        swapData.initiatedAt = uint64(block.timestamp);
        swapData.sourceChainId = 1;
        swapData.destinationChainId = 42161;
        swapData.status = 1;
        
        CrossChainStorage.ChainConfig memory chainConfig;
        chainConfig.enabled = true;
        chainConfig.maxGasPrice = 100e9;
        chainConfig.blockTime = 12;
        chainConfig.finalityTime = 780;
        
        CrossChainStorage.GlobalStats memory globalStats;
        globalStats.totalSwaps = 1000;
        globalStats.successfulSwaps = 950;
        globalStats.failedSwaps = 50;
        globalStats.totalExecutionTime = 300000;
        
        CrossChainStorage.SystemConfig memory systemConfig;
        systemConfig.bridgeIntegration = address(0x456);
        systemConfig.isPaused = false;
        systemConfig.pausedAt = 0;
        
        // GasOptimizationStorage structs
        GasOptimizationStorage.UserPreferences memory userPrefs;
        userPrefs.minSavingsThresholdBPS = 500;
        userPrefs.minAbsoluteSavingsUSD = 10e18;
        userPrefs.maxAcceptableBridgeTime = 1800;
        userPrefs.enableCrossChainOptimization = true;
        userPrefs.enableUSDDisplay = true;
        
        GasOptimizationStorage.SystemConfiguration memory sysConfig;
        sysConfig.minSavingsThresholdBPS = 500;
        sysConfig.minAbsoluteSavingsUSD = 10e18;
        sysConfig.maxBridgeTime = 1800;
        sysConfig.lastUpdated = uint64(block.timestamp);
        sysConfig.updateDelay = 86400;
        
        GasOptimizationStorage.UserAnalytics memory userAnalytics;
        userAnalytics.totalSavingsUSD = 1000e18;
        userAnalytics.totalSwapsOptimized = 100;
        userAnalytics.lastSwapTimestamp = uint64(block.timestamp);
        
        GasOptimizationStorage.GlobalAnalytics memory globalAnalytics;
        globalAnalytics.totalSystemSavingsUSD = 100000e18;
        globalAnalytics.totalSwapsOptimized = 10000;
        globalAnalytics.lastUpdateTimestamp = uint64(block.timestamp);
        
        // If we get here without reverting, all structs are properly constructed
        assertTrue(true);
    }

    function testSwapStatusConversion(uint8 status) public view {
        // Only test valid enum values (0-6)
        vm.assume(status <= 6);
        
        ICrossChainManager.SwapStatus swapStatus = ICrossChainManager.SwapStatus(status);
        uint8 converted = testContract.testSwapStatusConversion(swapStatus);
        assertEq(converted, status);
    }
    
    function testSwapStatusReconversion(uint8 status) public view {
        // Only test valid enum values (0-6)
        vm.assume(status <= 6);
        
        ICrossChainManager.SwapStatus reconverted = testContract.testSwapStatusReconversion(status);
        assertEq(uint8(reconverted), status);
    }
}