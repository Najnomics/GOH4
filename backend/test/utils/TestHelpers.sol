// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockChainlinkOracle} from "../mocks/MockChainlinkOracle.sol";
import {Constants} from "../../src/utils/Constants.sol";

/// @title Test Helpers for common testing utilities
contract TestHelpers is Test {
    
    /// @notice Create a mock Chainlink oracle with specified price
    function createMockOracle(int256 price, uint8 decimals, string memory description) 
        internal 
        returns (MockChainlinkOracle) 
    {
        return new MockChainlinkOracle(price, decimals, description);
    }
    
    /// @notice Create ETH/USD mock oracle with realistic price
    function createETHUSDOracle() internal returns (MockChainlinkOracle) {
        return createMockOracle(2000e8, 8, "ETH/USD"); // $2000 ETH
    }
    
    /// @notice Create USDC/USD mock oracle
    function createUSDCUSDOracle() internal returns (MockChainlinkOracle) {
        return createMockOracle(1e8, 8, "USDC/USD"); // $1 USDC
    }
    
    /// @notice Get realistic gas prices for testing
    function getRealisticGasPrices() internal pure returns (uint256[] memory chainIds, uint256[] memory prices) {
        chainIds = new uint256[](5);
        prices = new uint256[](5);
        
        // Ethereum - expensive
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        prices[0] = 50e9; // 50 gwei
        
        // Arbitrum - cheap
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        prices[1] = 0.1e9; // 0.1 gwei
        
        // Optimism - cheap
        chainIds[2] = Constants.OPTIMISM_CHAIN_ID;
        prices[2] = 0.001e9; // 0.001 gwei
        
        // Polygon - medium
        chainIds[3] = Constants.POLYGON_CHAIN_ID;
        prices[3] = 100e9; // 100 gwei (MATIC)
        
        // Base - cheap
        chainIds[4] = Constants.BASE_CHAIN_ID;
        prices[4] = 0.01e9; // 0.01 gwei
    }
    
    /// @notice Calculate expected savings for test scenarios
    function calculateExpectedSavings(uint256 originalCost, uint256 optimizedCost) 
        internal 
        pure 
        returns (uint256 savingsUSD, uint256 savingsPercentageBPS) 
    {
        if (optimizedCost >= originalCost) {
            return (0, 0);
        }
        
        savingsUSD = originalCost - optimizedCost;
        savingsPercentageBPS = (savingsUSD * Constants.BASIS_POINTS_DENOMINATOR) / originalCost;
    }
    
    /// @notice Create test swap parameters
    function createSwapParams(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 sourceChain,
        uint256 destChain
    ) internal view returns (
        address,
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        bytes memory
    ) {
        return (
            user,
            tokenIn,
            tokenOut,
            amountIn,
            sourceChain,
            destChain,
            block.timestamp + 3600, // 1 hour deadline
            ""
        );
    }
    
    /// @notice Assert savings meet threshold requirements
    function assertSavingsMeetThreshold(
        uint256 originalCost,
        uint256 optimizedCost,
        uint256 minSavingsThresholdBPS,
        uint256 minAbsoluteSavingsUSD,
        string memory message
    ) internal {
        (uint256 savingsUSD, uint256 savingsPercentageBPS) = calculateExpectedSavings(originalCost, optimizedCost);
        
        require(
            savingsPercentageBPS >= minSavingsThresholdBPS,
            string(abi.encodePacked(message, ": Percentage threshold not met"))
        );
        
        require(
            savingsUSD >= minAbsoluteSavingsUSD,
            string(abi.encodePacked(message, ": Absolute threshold not met"))
        );
    }
    
    /// @notice Simulate time passage for testing
    function simulateTimePassage(uint256 timeInSeconds) internal {
        vm.warp(block.timestamp + timeInSeconds);
    }
    
    /// @notice Generate random addresses for testing
    function generateRandomAddress(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }
    
    /// @notice Create array of test chain IDs
    function getTestChainIds() internal pure returns (uint256[] memory) {
        uint256[] memory chainIds = new uint256[](5);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        chainIds[2] = Constants.OPTIMISM_CHAIN_ID;
        chainIds[3] = Constants.POLYGON_CHAIN_ID;
        chainIds[4] = Constants.BASE_CHAIN_ID;
        return chainIds;
    }
}