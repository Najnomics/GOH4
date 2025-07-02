// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasCalculations} from "../../src/libraries/GasCalculations.sol";
import {ChainUtils} from "../../src/libraries/ChainUtils.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

/// @title Edge Case Coverage Tests
/// @notice Additional tests to achieve 100% code coverage
contract EdgeCaseCoverageTest is Test {
    using GasCalculations for uint256;

    function testGasCalculationsEdgeCases() public pure {
        // Test edge case: zero values
        uint256 zero = 0;
        assertEq(zero.calculateSavingsPercent(0), 0);
        assertEq(zero.calculateAbsoluteSavings(0), 0);
        
        // Test edge case: same values
        uint256 amount = 100e18;
        assertEq(amount.calculateSavingsPercent(amount), 0);
        assertEq(amount.calculateAbsoluteSavings(amount), 0);
        
        // Test edge case: maximum values
        uint256 maxUint = type(uint256).max;
        assertEq(maxUint.calculateSavingsPercent(maxUint - 1), 0); // Very small percentage
        
        // Test edge case: meetsSavingsThreshold with zero threshold
        assertTrue(amount.meetsSavingsThreshold(amount - 1, 0, 0));
        
        // Test edge case: meetsSavingsThreshold with maximum threshold
        assertFalse(amount.meetsSavingsThreshold(amount - 1, 10000, type(uint256).max));
    }

    function testGasCalculationsOverflow() public pure {
        // Test potential overflow scenarios
        uint256 largeAmount = type(uint128).max;
        uint256 result = largeAmount.calculateSavingsPercent(largeAmount / 2);
        assertEq(result, 5000); // 50% in basis points
        
        // Test safety margin application
        uint256 gasLimit = 100000;
        uint256 safetyMargin = 2000; // 20%
        uint256 adjustedGas = gasLimit.applyGasSafetyMargin(safetyMargin);
        assertEq(adjustedGas, 120000);
    }

    function testChainUtilsEdgeCases() public pure {
        // Test chain validation edge cases
        assertFalse(ChainUtils.isValidChainId(0));
        assertTrue(ChainUtils.isValidChainId(1));
        assertTrue(ChainUtils.isValidChainId(42161));
        assertTrue(ChainUtils.isValidChainId(137));
        assertTrue(ChainUtils.isValidChainId(10));
        assertTrue(ChainUtils.isValidChainId(8453));
        assertFalse(ChainUtils.isValidChainId(999999));
        
        // Test gas multiplier edge cases
        assertEq(ChainUtils.getGasMultiplier(1), 10000); // Ethereum: 100%
        assertEq(ChainUtils.getGasMultiplier(42161), 15000); // Arbitrum: 150%
        assertEq(ChainUtils.getGasMultiplier(999999), 10000); // Unknown: default 100%
    }

    function testConstantsValidation() public pure {
        // Validate all constants are within expected ranges
        assertTrue(Constants.BASIS_POINTS_DENOMINATOR == 10000);
        assertTrue(Constants.DEFAULT_MIN_SAVINGS_BPS >= 0);
        assertTrue(Constants.DEFAULT_MIN_SAVINGS_BPS <= Constants.BASIS_POINTS_DENOMINATOR);
        assertTrue(Constants.DEFAULT_MIN_ABSOLUTE_SAVINGS_USD > 0);
        assertTrue(Constants.MAX_BRIDGE_TIME > 0);
        assertTrue(Constants.GAS_ESTIMATION_MULTIPLIER >= Constants.BASIS_POINTS_DENOMINATOR);
    }

    function testErrorsExistence() public {
        // Test that all error types can be created (for coverage)
        try this.throwZeroAddress() {
            fail();
        } catch (bytes memory data) {
            // Expected to catch the error
            assertTrue(data.length > 0);
        }
        
        try this.throwZeroAmount() {
            fail();
        } catch (bytes memory data) {
            assertTrue(data.length > 0);
        }
    }

    // Helper functions to test error throwing
    function throwZeroAddress() external pure {
        revert Errors.ZeroAddress();
    }
    
    function throwZeroAmount() external pure {
        revert Errors.ZeroAmount();
    }

    function testBasisPointsConversion() public pure {
        // Test basis points to percentage conversions
        assertEq(GasCalculations.basisPointsToPercentage(100), 1); // 1%
        assertEq(GasCalculations.basisPointsToPercentage(500), 5); // 5%
        assertEq(GasCalculations.basisPointsToPercentage(10000), 100); // 100%
        assertEq(GasCalculations.basisPointsToPercentage(0), 0); // 0%
        
        // Test percentage to basis points conversions
        assertEq(GasCalculations.percentageToBasisPoints(1), 100);
        assertEq(GasCalculations.percentageToBasisPoints(5), 500);
        assertEq(GasCalculations.percentageToBasisPoints(100), 10000);
        assertEq(GasCalculations.percentageToBasisPoints(0), 0);
    }

    function testGasEstimations() public pure {
        // Test various gas estimation scenarios
        uint256 baseGas = 21000;
        
        // Test simple transfer
        uint256 transferGas = GasCalculations.estimateTransferGas();
        assertGt(transferGas, baseGas);
        
        // Test swap gas estimation
        uint256 swapGas = GasCalculations.estimateSwapGas();
        assertGt(swapGas, transferGas);
        
        // Test cross-chain gas estimation
        uint256 bridgeGas = GasCalculations.estimateBridgeGas();
        assertGt(bridgeGas, swapGas);
    }

    function testCrossChainGasUsage() public pure {
        // Test cross-chain gas calculations
        uint256 sourceGas = 100000;
        uint256 destGas = 80000;
        uint256 bridgeGas = 50000;
        
        uint256 totalGas = GasCalculations.calculateCombinedGasUsage(
            sourceGas,
            destGas,
            bridgeGas
        );
        
        assertEq(totalGas, sourceGas + destGas + bridgeGas);
    }

    function testGasCostCalculations() public pure {
        // Test gas cost calculations in wei
        uint256 gasUsed = 100000;
        uint256 gasPrice = 20e9; // 20 gwei
        
        uint256 costWei = GasCalculations.calculateGasCostWei(gasUsed, gasPrice);
        assertEq(costWei, gasUsed * gasPrice);
    }
}