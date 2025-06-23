// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasCalculations} from "../../src/libraries/GasCalculations.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract GasCalculationsTest is Test {
    using GasCalculations for uint256;

    function testCalculateSavingsPercent() public {
        uint256 originalCost = 100e18; // $100
        uint256 optimizedCost = 80e18; // $80
        
        uint256 savingsPercent = originalCost.calculateSavingsPercent(optimizedCost);
        assertEq(savingsPercent, 2000); // 20% in basis points
    }

    function testCalculateSavingsPercentNoSavings() public {
        uint256 originalCost = 100e18;
        uint256 optimizedCost = 120e18; // More expensive
        
        uint256 savingsPercent = originalCost.calculateSavingsPercent(optimizedCost);
        assertEq(savingsPercent, 0);
    }

    function testCalculateAbsoluteSavings() public {
        uint256 originalCost = 100e18;
        uint256 optimizedCost = 80e18;
        
        uint256 absoluteSavings = originalCost.calculateAbsoluteSavings(optimizedCost);
        assertEq(absoluteSavings, 20e18);
    }

    function testMeetsSavingsThreshold() public {
        uint256 originalCost = 100e18;
        uint256 optimizedCost = 80e18; // 20% savings, $20 absolute
        
        // Should meet threshold: 20% >= 5% and $20 >= $10
        bool meetsThreshold = originalCost.meetsSavingsThreshold(
            optimizedCost,
            500, // 5% minimum
            10e18 // $10 minimum
        );
        assertTrue(meetsThreshold);
    }

    function testDoesNotMeetPercentageThreshold() public {
        uint256 originalCost = 100e18;
        uint256 optimizedCost = 98e18; // 2% savings, $2 absolute
        
        // Should not meet percentage threshold: 2% < 5%
        bool meetsThreshold = originalCost.meetsSavingsThreshold(
            optimizedCost,
            500, // 5% minimum
            1e18 // $1 minimum
        );
        assertFalse(meetsThreshold);
    }

    function testDoesNotMeetAbsoluteThreshold() public {
        uint256 originalCost = 10e18;
        uint256 optimizedCost = 5e18; // 50% savings, $5 absolute
        
        // Should not meet absolute threshold: $5 < $10
        bool meetsThreshold = originalCost.meetsSavingsThreshold(
            optimizedCost,
            500, // 5% minimum
            10e18 // $10 minimum
        );
        assertFalse(meetsThreshold);
    }

    function testApplyGasSafetyMargin() public {
        uint256 baseGasCost = 100e18;
        uint256 safetyMarginBPS = 2000; // 20%
        
        uint256 adjustedCost = baseGasCost.applyGasSafetyMargin(safetyMarginBPS);
        assertEq(adjustedCost, 120e18); // 100 + 20% = 120
    }

    function testGasEstimations() public {
        assertEq(GasCalculations.estimateTransferGas(), 21000);
        assertEq(GasCalculations.estimateTokenTransferGas(), 65000);
        assertEq(GasCalculations.estimateSwapGas(), 120000);
        assertEq(GasCalculations.estimateBridgeGas(), 150000);
    }

    function testCalculateCrossChainGasUsage() public {
        uint256 gasWithoutReturn = GasCalculations.calculateCrossChainGasUsage(false);
        uint256 gasWithReturn = GasCalculations.calculateCrossChainGasUsage(true);
        
        assertEq(gasWithoutReturn, 270000); // bridge + swap
        assertEq(gasWithReturn, 420000); // bridge + swap + bridge
    }

    function testValidateGasPrice() public {
        assertTrue((20e9).validateGasPrice()); // 20 gwei - valid
        assertFalse((0).validateGasPrice()); // 0 - invalid
        assertFalse((2000e9).validateGasPrice()); // Too high - invalid
    }

    function testCalculateGasCostWei() public {
        uint256 gasUsage = 120000;
        uint256 gasPrice = 20e9; // 20 gwei
        
        uint256 gasCost = GasCalculations.calculateGasCostWei(gasUsage, gasPrice);
        assertEq(gasCost, gasUsage * gasPrice);
    }

    function testBasisPointsToPercentage() public {
        assertEq(GasCalculations.basisPointsToPercentage(500), 5); // 5%
        assertEq(GasCalculations.basisPointsToPercentage(2500), 25); // 25%
        assertEq(GasCalculations.basisPointsToPercentage(10000), 100); // 100%
    }
}