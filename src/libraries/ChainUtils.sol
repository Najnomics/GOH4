// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";

/// @title Chain-specific utilities
library ChainUtils {
    /// @notice Get chain name for a given chain ID
    /// @param chainId Chain ID to look up
    /// @return name Chain name
    function getChainName(uint256 chainId) internal pure returns (string memory name) {
        if (chainId == Constants.ETHEREUM_CHAIN_ID) return "Ethereum";
        if (chainId == Constants.ARBITRUM_CHAIN_ID) return "Arbitrum";
        if (chainId == Constants.OPTIMISM_CHAIN_ID) return "Optimism";
        if (chainId == Constants.POLYGON_CHAIN_ID) return "Polygon";
        if (chainId == Constants.BASE_CHAIN_ID) return "Base";
        return "Unknown";
    }

    /// @notice Check if chain ID is supported
    /// @param chainId Chain ID to validate
    /// @return isSupported True if chain is supported
    function isSupportedChain(uint256 chainId) internal pure returns (bool isSupported) {
        return chainId == Constants.ETHEREUM_CHAIN_ID || chainId == Constants.ARBITRUM_CHAIN_ID
            || chainId == Constants.OPTIMISM_CHAIN_ID || chainId == Constants.POLYGON_CHAIN_ID
            || chainId == Constants.BASE_CHAIN_ID;
    }

    /// @notice Alias for isSupportedChain for test compatibility
    /// @param chainId Chain ID to validate
    /// @return isValid True if chain is valid/supported
    function isValidChainId(uint256 chainId) internal pure returns (bool isValid) {
        return isSupportedChain(chainId);
    }

    /// @notice Get all supported chain IDs
    /// @return chainIds Array of supported chain IDs
    function getSupportedChains() internal pure returns (uint256[] memory chainIds) {
        chainIds = new uint256[](5);
        chainIds[0] = Constants.ETHEREUM_CHAIN_ID;
        chainIds[1] = Constants.ARBITRUM_CHAIN_ID;
        chainIds[2] = Constants.OPTIMISM_CHAIN_ID;
        chainIds[3] = Constants.POLYGON_CHAIN_ID;
        chainIds[4] = Constants.BASE_CHAIN_ID;
    }

    /// @notice Validate chain ID
    /// @param chainId Chain ID to validate
    function validateChainId(uint256 chainId) internal pure {
        if (!isSupportedChain(chainId)) {
            revert Errors.InvalidChainId();
        }
    }

    /// @notice Get typical block time for a chain
    /// @param chainId Chain ID
    /// @return blockTime Block time in seconds
    function getBlockTime(uint256 chainId) internal pure returns (uint256 blockTime) {
        if (chainId == Constants.ETHEREUM_CHAIN_ID) return 12;
        if (chainId == Constants.ARBITRUM_CHAIN_ID) return 1;
        if (chainId == Constants.OPTIMISM_CHAIN_ID) return 2;
        if (chainId == Constants.POLYGON_CHAIN_ID) return 2;
        if (chainId == Constants.BASE_CHAIN_ID) return 2;
        return 12; // Default to Ethereum block time
    }

    /// @notice Get finality time for a chain
    /// @param chainId Chain ID
    /// @return finalityTime Finality time in seconds
    function getFinalityTime(uint256 chainId) internal pure returns (uint256 finalityTime) {
        if (chainId == Constants.ETHEREUM_CHAIN_ID) return 780; // ~65 blocks * 12 seconds
        if (chainId == Constants.ARBITRUM_CHAIN_ID) return 1200; // ~20 minutes for L1 finality
        if (chainId == Constants.OPTIMISM_CHAIN_ID) return 1200; // ~20 minutes for L1 finality
        if (chainId == Constants.POLYGON_CHAIN_ID) return 256; // ~128 blocks * 2 seconds
        if (chainId == Constants.BASE_CHAIN_ID) return 1200; // ~20 minutes for L1 finality
        return 780; // Default to Ethereum finality
    }

    /// @notice Check if chain is Layer 2
    /// @param chainId Chain ID
    /// @return isL2 True if chain is Layer 2
    function isLayer2(uint256 chainId) internal pure returns (bool isL2) {
        return chainId == Constants.ARBITRUM_CHAIN_ID || chainId == Constants.OPTIMISM_CHAIN_ID
            || chainId == Constants.BASE_CHAIN_ID;
    }

    /// @notice Get gas multiplier for chain (in basis points)
    /// @param chainId Chain ID
    /// @return multiplier Gas multiplier in basis points (10000 = 100%)
    function getGasMultiplier(uint256 chainId) internal pure returns (uint256 multiplier) {
        if (chainId == Constants.ETHEREUM_CHAIN_ID) return 10000; // 100%
        if (chainId == Constants.ARBITRUM_CHAIN_ID) return 11000; // 110%
        if (chainId == Constants.OPTIMISM_CHAIN_ID) return 11000; // 110%
        if (chainId == Constants.POLYGON_CHAIN_ID) return 12000; // 120%
        if (chainId == Constants.BASE_CHAIN_ID) return 11000; // 110%
        return 12000; // Default multiplier
    }

    /// @notice Get bridge time estimate to destination chain
    /// @param sourceChainId Source chain ID
    /// @param destinationChainId Destination chain ID
    /// @return bridgeTime Estimated bridge time in seconds
    function getBridgeTime(uint256 sourceChainId, uint256 destinationChainId)
        internal
        pure
        returns (uint256 bridgeTime)
    {
        // Across protocol typical bridge times
        if (sourceChainId == destinationChainId) return 0;
        
        // Ethereum to L2 or L2 to Ethereum: ~2-5 minutes
        if (sourceChainId == Constants.ETHEREUM_CHAIN_ID || destinationChainId == Constants.ETHEREUM_CHAIN_ID) {
            return 300; // 5 minutes
        }
        
        // L2 to L2: ~5-10 minutes
        return 600; // 10 minutes
    }

    /// @notice Calculate network congestion multiplier
    /// @param gasPrice Current gas price
    /// @param chainId Chain ID
    /// @return multiplier Congestion multiplier (100 = 1x, 200 = 2x)
    function getCongestionMultiplier(uint256 gasPrice, uint256 chainId) internal pure returns (uint256 multiplier) {
        // Base gas price thresholds for different chains
        uint256 baseGasPrice;
        
        if (chainId == Constants.ETHEREUM_CHAIN_ID) {
            baseGasPrice = 20 gwei;
        } else if (chainId == Constants.POLYGON_CHAIN_ID) {
            baseGasPrice = 100 gwei;
        } else {
            baseGasPrice = 1 gwei; // L2s
        }
        
        if (gasPrice <= baseGasPrice) return 100; // No congestion
        if (gasPrice <= baseGasPrice * 2) return 120; // Low congestion
        if (gasPrice <= baseGasPrice * 5) return 150; // Medium congestion
        return 200; // High congestion
    }
}