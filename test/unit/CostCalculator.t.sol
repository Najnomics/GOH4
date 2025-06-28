// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";
import {ICostCalculator} from "../../src/interfaces/ICostCalculator.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {MockChainlinkIntegration} from "../mocks/MockChainlinkIntegration.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract CostCalculatorTest is Test {
    CostCalculator calculator;
    GasPriceOracle oracle;
    MockChainlinkIntegration mockChainlink;
    MockPriceFeed mockPriceFeed;
    address owner = address(0x1);
    address keeper = address(0x2);
    address user = address(0x3);

    function setUp() public {
        oracle = new GasPriceOracle(owner, keeper);
        mockChainlink = new MockChainlinkIntegration();
        mockPriceFeed = new MockPriceFeed();
        calculator = new CostCalculator(owner, address(oracle), address(mockChainlink));
        
        // Setup mock price feeds for all supported chains
        vm.startPrank(owner);
        oracle.addChain(Constants.ETHEREUM_CHAIN_ID, address(mockPriceFeed));
        oracle.addChain(Constants.ARBITRUM_CHAIN_ID, address(mockPriceFeed));
        oracle.addChain(Constants.OPTIMISM_CHAIN_ID, address(mockPriceFeed));
        oracle.addChain(Constants.POLYGON_CHAIN_ID, address(mockPriceFeed));
        oracle.addChain(Constants.BASE_CHAIN_ID, address(mockPriceFeed));
        vm.stopPrank();
        
        // Setup initial gas prices for all supported chains
        vm.prank(keeper);
        uint256[] memory chainIds = new uint256[](5);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        chainIds[2] = Constants.OPTIMISM_CHAIN_ID;
        chainIds[3] = Constants.POLYGON_CHAIN_ID;
        chainIds[4] = Constants.BASE_CHAIN_ID;
        
        uint256[] memory prices = new uint256[](5);
        prices[0] = 50e9; // 50 gwei (expensive)
        prices[1] = 1e9;  // 1 gwei (cheap)
        prices[2] = 2e9;  // 2 gwei (medium)
        prices[3] = 100e9; // 100 gwei (very expensive - Polygon)
        prices[4] = 1.5e9; // 1.5 gwei (cheap)
        
        oracle.updateGasPrices(chainIds, prices);
    }

    function testCalculateTotalCost() public {
        // Set chain ID to Ethereum for this test
        vm.chainId(Constants.ETHEREUM_CHAIN_ID);
        
        ICostCalculator.CostParams memory params = ICostCalculator.CostParams({
            chainId: Constants.ETHEREUM_CHAIN_ID,
            tokenIn: address(0x1),
            tokenOut: address(0x2),
            amountIn: 1e18,
            gasLimit: 120000,
            user: user,
            gasUsed: 120000,
            gasPrice: 20e9
        });
        
        ICostCalculator.TotalCost memory cost = calculator.calculateTotalCost(params);
        
        assertGt(cost.gasCostUSD, 0);
        assertEq(cost.bridgeFeeUSD, 0); // No bridge fee for same chain
        assertGt(cost.totalCostUSD, 0);
    }

    function testFindOptimalChain() public {
        // Set chain ID to Ethereum for this test
        vm.chainId(Constants.ETHEREUM_CHAIN_ID);
        
        ICostCalculator.OptimizationParams memory params = ICostCalculator.OptimizationParams({
            tokenIn: address(0x1),
            tokenOut: address(0x2),
            amountIn: 1e18,
            minSavingsThresholdBPS: 500, // 5%
            minAbsoluteSavingsUSD: 5e18, // $5
            maxBridgeTime: 1800, // 30 minutes
            excludeChains: new uint256[](0)
        });
        
        (uint256 optimalChainId, uint256 expectedSavings) = calculator.findOptimalChain(params);
        
        // Should find a cheaper chain if savings meet threshold
        if (expectedSavings > 0) {
            assertNotEq(optimalChainId, Constants.ETHEREUM_CHAIN_ID);
        }
    }

    function testCalculateGasCostUSD() public {
        // This test now works with our mock setup
        uint256 gasCost = calculator.calculateGasCostUSD(Constants.ETHEREUM_CHAIN_ID, 120000);
        assertGt(gasCost, 0);
    }

    function testCalculateBridgeFeeUSD() public view {
        uint256 bridgeFee = calculator.calculateBridgeFeeUSD(
            address(0x1),
            1e18,
            Constants.ARBITRUM_CHAIN_ID
        );
        
        // Should return base bridge fee since we can get token price from mock
        assertGt(bridgeFee, 0);
    }

    function testUpdateCostParameters() public {
        ICostCalculator.CostParameters memory newParams = ICostCalculator.CostParameters({
            baseBridgeFeeUSD: 5e18, // $5
            bridgeFeePercentageBPS: 20, // 0.2%
            maxSlippageBPS: 100, // 1%
            mevProtectionFeeBPS: 10, // 0.1%
            gasEstimationMultiplier: 15000 // 1.5x in basis points
        });
        
        vm.prank(owner);
        calculator.updateCostParameters(newParams);
        
        (
            uint256 baseBridgeFeeUSD,
            uint256 bridgeFeePercentageBPS,
            uint256 maxSlippageBPS,
            uint256 mevProtectionFeeBPS,
            uint256 gasEstimationMultiplier
        ) = calculator.costParameters();
        assertEq(baseBridgeFeeUSD, 5e18);
        assertEq(bridgeFeePercentageBPS, 20);
    }

    function testOnlyOwnerCanUpdateParameters() public {
        ICostCalculator.CostParameters memory newParams = ICostCalculator.CostParameters({
            baseBridgeFeeUSD: 5e18,
            bridgeFeePercentageBPS: 20,
            maxSlippageBPS: 100,
            mevProtectionFeeBPS: 10,
            gasEstimationMultiplier: 15000 // 1.5x in basis points
        });
        
        vm.prank(user);
        vm.expectRevert();
        calculator.updateCostParameters(newParams);
    }

    function testIsCostCalculationReliable() public view {
        bool reliable = calculator.isCostCalculationReliable(Constants.ETHEREUM_CHAIN_ID);
        assertTrue(reliable); // Should be reliable with fresh gas prices
    }

    // Additional tests to improve coverage
    function testCalculateSlippageCost() public {
        uint256 amount = 1000e18;
        uint256 slippageBPS = 50; // 0.5%
        
        uint256 slippageCost = calculator.calculateSlippageCost(amount, slippageBPS);
        assertEq(slippageCost, amount * slippageBPS / 10000);
    }

    function testCalculateMEVProtectionFee() public {
        uint256 amount = 1000e18;
        uint256 mevFeeBPS = 10; // 0.1%
        
        uint256 mevFee = calculator.calculateMEVProtectionFee(amount, mevFeeBPS);
        assertEq(mevFee, amount * mevFeeBPS / 10000);
    }

    function testValidateChainSupport() public view {
        assertTrue(calculator.isChainSupported(Constants.ETHEREUM_CHAIN_ID));
        assertTrue(calculator.isChainSupported(Constants.ARBITRUM_CHAIN_ID));
        assertFalse(calculator.isChainSupported(999999)); // Unsupported chain
    }

    function testGetCostBreakdown() public {
        ICostCalculator.CostParams memory params = ICostCalculator.CostParams({
            gasUsed: 200000,
            gasPrice: 30e9,
            tokenIn: address(0),
            tokenOut: address(0x123),
            amountIn: 1000e18,
            chainId: Constants.ETHEREUM_CHAIN_ID,
            gasLimit: 200000,
            user: address(this)
        });
        
        ICostCalculator.TotalCost memory cost = calculator.calculateTotalCost(params);
        
        // Verify all components are calculated
        assertGt(cost.gasCostUSD, 0);
        assertGt(cost.bridgeFeeUSD, 0);
        assertGt(cost.totalCostUSD, cost.gasCostUSD);
    }

    function testEmergencyConfiguration() public {
        // Test emergency settings
        ICostCalculator.CostParameters memory emergencyParams = ICostCalculator.CostParameters({
            baseBridgeFeeUSD: 1e18, // $1
            bridgeFeePercentageBPS: 5, // 0.05%
            maxSlippageBPS: 500, // 5%
            mevProtectionFeeBPS: 50, // 0.5%
            gasEstimationMultiplier: 20000 // 2x
        });
        
        vm.prank(owner);
        calculator.updateCostParameters(emergencyParams);
        
        // Verify parameters updated
        ICostCalculator.CostParameters memory updated = calculator.getCostParameters();
        assertEq(updated.baseBridgeFeeUSD, 1e18);
        assertEq(updated.gasEstimationMultiplier, 20000);
    }

    function testCostCalculationWithDifferentTokens() public {
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xa0b86A33E6C4B4C2Cc6c1c4CdbBD0d8C7B4e5d2A;
        
        ICostCalculator.CostParams memory ethParams = ICostCalculator.CostParams({
            gasUsed: 150000,
            gasPrice: 25e9,
            tokenIn: address(0), // ETH
            tokenOut: usdc,
            amountIn: 10e18,
            chainId: Constants.ETHEREUM_CHAIN_ID,
            gasLimit: 150000,
            user: address(this)
        });
        
        ICostCalculator.CostParams memory tokenParams = ICostCalculator.CostParams({
            gasUsed: 150000,
            gasPrice: 25e9,
            tokenIn: weth,
            tokenOut: usdc,
            amountIn: 10e18,
            chainId: Constants.ETHEREUM_CHAIN_ID,
            gasLimit: 150000,
            user: address(this)
        });
        
        ICostCalculator.TotalCost memory ethCost = calculator.calculateTotalCost(ethParams);
        ICostCalculator.TotalCost memory tokenCost = calculator.calculateTotalCost(tokenParams);
        
        // Both should have reasonable costs
        assertGt(ethCost.totalCostUSD, 0);
        assertGt(tokenCost.totalCostUSD, 0);
    }

    function testInvalidParameterValidation() public {
        // Test invalid gas estimation multiplier
        ICostCalculator.CostParameters memory invalidParams = ICostCalculator.CostParameters({
            baseBridgeFeeUSD: 5e18,
            bridgeFeePercentageBPS: 20,
            maxSlippageBPS: 100,
            mevProtectionFeeBPS: 10,
            gasEstimationMultiplier: 50000 // 5x (too high)
        });
        
        vm.prank(owner);
        vm.expectRevert();
        calculator.updateCostParameters(invalidParams);
    }

    function testCostParametersGetters() public view {
        ICostCalculator.CostParameters memory params = calculator.getCostParameters();
        
        assertGt(params.baseBridgeFeeUSD, 0);
        assertGt(params.bridgeFeePercentageBPS, 0);
        assertGt(params.maxSlippageBPS, 0);
        assertGt(params.gasEstimationMultiplier, 0);
    }

    function testCrossChainCostComparison() public {
        vm.chainId(Constants.ETHEREUM_CHAIN_ID);
        
        ICostCalculator.OptimizationParams memory params = ICostCalculator.OptimizationParams({
            tokenIn: address(0),
            tokenOut: address(0x123),
            amountIn: 5000e18,
            minSavingsThresholdBPS: 300,
            minAbsoluteSavingsUSD: 10e18,
            maxBridgeTime: 1800,
            excludeChains: new uint256[](0)
        });
        
        (uint256 optimalChain, uint256 expectedSavings) = calculator.findOptimalChain(params);
        
        // Should find an optimal chain with some savings
        assertNotEq(optimalChain, Constants.ETHEREUM_CHAIN_ID); // Should suggest different chain
        assertGt(expectedSavings, 0);
    }
}