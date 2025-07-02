// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GasPriceOracle} from "../../src/core/GasPriceOracle.sol";
import {CostCalculator} from "../../src/core/CostCalculator.sol";
import {CrossChainManager} from "../../src/core/CrossChainManager.sol";
import {ICostCalculator} from "../../src/interfaces/ICostCalculator.sol";
import {ICrossChainManager} from "../../src/interfaces/ICrossChainManager.sol";
import {MockChainlinkIntegration} from "../mocks/MockChainlinkIntegration.sol";
import {MockSpokePool} from "../mocks/MockSpokePool.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";
import {Events} from "../../src/utils/Events.sol";

/// @title Admin Functions and Error Scenarios Test
/// @notice Tests for admin functions, error conditions, and edge cases
contract AdminAndErrorTest is Test {
    GasPriceOracle oracle;
    CostCalculator calculator;
    CrossChainManager manager;
    MockChainlinkIntegration mockChainlink;
    MockSpokePool mockSpokePool;

    address owner = address(0x1);
    address keeper = address(0x2);
    address user = address(0x3);
    address unauthorized = address(0x4);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock contracts
        mockChainlink = new MockChainlinkIntegration();
        mockSpokePool = new MockSpokePool();

        // Deploy main contracts
        oracle = new GasPriceOracle(owner, keeper);
        manager = new CrossChainManager(owner, address(mockSpokePool));
        calculator = new CostCalculator(
            owner,
            address(oracle),
            address(mockChainlink)
        );

        vm.stopPrank();
    }

    function testOracleAdminFunctions() public {
        vm.startPrank(owner);

        // Test adding chains
        oracle.addChain(999, address(mockChainlink));
        assertTrue(oracle.supportedChains(999));

        // Test removing chains
        oracle.removeChain(999);
        assertFalse(oracle.supportedChains(999));

        // Test keeper management
        oracle.setKeeper(address(0x5));
        assertEq(oracle.keeper(), address(0x5));

        // Test emergency pause
        oracle.pause();
        assertTrue(oracle.paused());

        oracle.unpause();
        assertFalse(oracle.paused());

        vm.stopPrank();
    }

    function testOracleUnauthorizedAccess() public {
        vm.startPrank(unauthorized);

        // Test unauthorized addChain
        vm.expectRevert();
        oracle.addChain(999, address(mockChainlink));

        // Test unauthorized removeChain
        vm.expectRevert();
        oracle.removeChain(1);

        // Test unauthorized keeper change
        vm.expectRevert();
        oracle.setKeeper(unauthorized);

        // Test unauthorized pause
        vm.expectRevert();
        oracle.pause();

        vm.stopPrank();
    }

    function testKeeperOnlyFunctions() public {
        // Setup gas prices array
        uint256[] memory chainIds = new uint256[](2);
        uint256[] memory gasPrices = new uint256[](2);
        chainIds[0] = 1;
        chainIds[1] = 42161;
        gasPrices[0] = 50e9; // 50 gwei
        gasPrices[1] = 1e9;  // 1 gwei

        vm.startPrank(keeper);
        oracle.updateGasPrices(chainIds, gasPrices);
        vm.stopPrank();

        // Verify updates
        (uint256 ethPrice, ) = oracle.getGasPrice(1);
        (uint256 arbPrice, ) = oracle.getGasPrice(42161);
        assertEq(ethPrice, 50e9);
        assertEq(arbPrice, 1e9);

        // Test unauthorized keeper function
        vm.startPrank(unauthorized);
        vm.expectRevert();
        oracle.updateGasPrices(chainIds, gasPrices);
        vm.stopPrank();
    }

    function testCalculatorErrorConditions() public {
        // Test with invalid chain ID
        ICostCalculator.CostParams memory params = ICostCalculator.CostParams({
            chainId: 999999,
            tokenIn: address(0x1001),
            tokenOut: address(0x1002),
            amountIn: 1e18,
            gasLimit: 100000,
            user: user,
            gasUsed: 0,
            gasPrice: 0
        });

        vm.expectRevert();
        calculator.calculateTotalCost(params);

        // Test with zero amount
        params.chainId = 1;
        params.amountIn = 0;
        vm.expectRevert();
        calculator.calculateTotalCost(params);

        // Test with zero addresses
        params.amountIn = 1e18;
        params.tokenIn = address(0);
        vm.expectRevert();
        calculator.calculateTotalCost(params);
    }

    function testManagerErrorConditions() public {
        // Test invalid cross-chain swap parameters
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: address(0),  // Invalid: zero address
            tokenIn: address(0x1001),
            tokenOut: address(0x1002),
            amountIn: 1e18,
            minAmountOut: 0.9e18,
            sourceChainId: 1,
            destinationChainId: 42161,
            deadline: block.timestamp + 3600,
            swapData: ""
        });

        vm.expectRevert(Errors.ZeroAddress.selector);
        manager.initiateCrossChainSwap(params);

        // Test with zero amount
        params.user = user;
        params.amountIn = 0;
        vm.expectRevert(Errors.ZeroAmount.selector);
        manager.initiateCrossChainSwap(params);

        // Test with expired deadline
        params.amountIn = 1e18;
        params.deadline = block.timestamp - 1;
        vm.expectRevert();
        manager.initiateCrossChainSwap(params);

        // Test with unsupported chain
        params.deadline = block.timestamp + 3600;
        params.destinationChainId = 999999;
        vm.expectRevert();
        manager.initiateCrossChainSwap(params);
    }

    function testOracleGasPriceValidation() public {
        vm.startPrank(keeper);

        // Test invalid gas price arrays (mismatched lengths)
        uint256[] memory chainIds = new uint256[](2);
        uint256[] memory gasPrices = new uint256[](1); // Different length
        chainIds[0] = 1;
        chainIds[1] = 42161;
        gasPrices[0] = 50e9;

        vm.expectRevert();
        oracle.updateGasPrices(chainIds, gasPrices);

        // Test empty arrays
        uint256[] memory emptyChainIds = new uint256[](0);
        uint256[] memory emptyGasPrices = new uint256[](0);
        vm.expectRevert();
        oracle.updateGasPrices(emptyChainIds, emptyGasPrices);

        vm.stopPrank();
    }

    function testOracleStaleData() public {
        vm.startPrank(keeper);

        // Set initial gas prices
        uint256[] memory chainIds = new uint256[](1);
        uint256[] memory gasPrices = new uint256[](1);
        chainIds[0] = 1;
        gasPrices[0] = 50e9;

        oracle.updateGasPrices(chainIds, gasPrices);

        // Fast forward time to make data stale
        vm.warp(block.timestamp + 3600); // 1 hour later

        // Check if stale detection works
        assertTrue(oracle.isGasPriceStale(1));

        vm.stopPrank();
    }

    function testManagerPauseFunctionality() public {
        vm.startPrank(owner);

        // Test pause functionality
        manager.pause();
        assertTrue(manager.isPaused());

        // Test that operations fail when paused
        ICrossChainManager.CrossChainSwapParams memory params = ICrossChainManager.CrossChainSwapParams({
            user: user,
            tokenIn: address(0x1001),
            tokenOut: address(0x1002),
            amountIn: 1e18,
            minAmountOut: 0.9e18,
            sourceChainId: 1,
            destinationChainId: 42161,
            deadline: block.timestamp + 3600,
            swapData: ""
        });

        vm.expectRevert();
        manager.initiateCrossChainSwap(params);

        // Test unpause
        manager.unpause();
        assertFalse(manager.isPaused());

        vm.stopPrank();
    }

    function testCalculatorParameterUpdates() public {
        vm.startPrank(owner);

        // Test updating cost parameters
        ICostCalculator.CostParameters memory newParams = ICostCalculator.CostParameters({
            baseBridgeFeeUSD: 5e18, // $5
            bridgeFeePercentageBPS: 20, // 0.2%
            maxSlippageBPS: 100, // 1%
            mevProtectionFeeBPS: 10, // 0.1%
            gasEstimationMultiplier: 13000 // 1.3x
        });

        calculator.updateCostParameters(newParams);

        // Verify parameters were updated
        ICostCalculator.CostParameters memory currentParams = calculator.getCostParameters();
        assertEq(currentParams.baseBridgeFeeUSD, 5e18);
        assertEq(currentParams.bridgeFeePercentageBPS, 20);

        vm.stopPrank();

        // Test unauthorized parameter update
        vm.startPrank(unauthorized);
        vm.expectRevert();
        calculator.updateCostParameters(newParams);
        vm.stopPrank();
    }

    function testEventEmissions() public {
        vm.startPrank(keeper);

        // Test gas price update event
        uint256[] memory chainIds = new uint256[](1);
        uint256[] memory gasPrices = new uint256[](1);
        chainIds[0] = 1;
        gasPrices[0] = 50e9;

        vm.expectEmit(true, true, true, true);
        emit Events.GasPriceUpdated(chainIds[0], gasPrices[0], block.timestamp);
        oracle.updateGasPrices(chainIds, gasPrices);

        vm.stopPrank();
    }

    function testRecoveryFunctions() public {
        vm.startPrank(owner);

        // Test recovery functionality if implemented
        // This would test any emergency recovery functions
        
        vm.stopPrank();
    }
}