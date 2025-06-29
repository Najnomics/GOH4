// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICrossChainManager} from "../interfaces/ICrossChainManager.sol";

/// @title Cross Chain Storage layout for state management
library CrossChainStorage {
    struct Layout {
        // Swap state mapping
        mapping(bytes32 => SwapData) swapStates;
        
        // User active swaps
        mapping(address => bytes32[]) userActiveSwaps;
        
        // Chain configurations
        mapping(uint256 => ChainConfig) chainConfigs;
        
        // Global statistics
        GlobalStats globalStats;
        
        // System configuration
        SystemConfig systemConfig;
        
        // Upgrade storage
        uint256[50] __gap;
    }

    struct SwapData {
        address user;                       // 160 bits
        uint64 initiatedAt;                 // 64 bits
        uint32 sourceChainId;               // 32 bits
        // Total: 256 bits (1 slot)
        
        uint32 destinationChainId;          // 32 bits
        uint8 status;                       // 8 bits (SwapStatus enum)
        uint216 reserved1;                  // 216 bits reserved
        // Total: 256 bits (1 slot)
        
        address tokenIn;                    // 160 bits
        uint96 amountIn;                    // 96 bits
        // Total: 256 bits (1 slot)
        
        address tokenOut;                   // 160 bits
        uint96 amountOut;                   // 96 bits
        // Total: 256 bits (1 slot)
        
        uint64 completedAt;                 // 64 bits
        bytes32 bridgeTransactionId;        // 256 bits
        // Total: 320 bits (2 slots)
    }

    struct ChainConfig {
        bool enabled;                       // 8 bits
        uint64 maxGasPrice;                 // 64 bits
        uint64 blockTime;                   // 64 bits
        uint64 finalityTime;                // 64 bits
        uint56 reserved;                    // 56 bits reserved
        // Total: 256 bits (1 slot)
    }

    struct GlobalStats {
        uint64 totalSwaps;                  // 64 bits
        uint64 successfulSwaps;             // 64 bits
        uint64 failedSwaps;                 // 64 bits
        uint64 totalExecutionTime;          // 64 bits
        // Total: 256 bits (1 slot)
    }

    struct SystemConfig {
        address bridgeIntegration;          // 160 bits
        bool isPaused;                      // 8 bits
        uint64 pausedAt;                    // 64 bits
        uint24 reserved;                    // 24 bits reserved
        // Total: 256 bits (1 slot)
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("crosschain.storage.layout");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function convertSwapStatus(ICrossChainManager.SwapStatus status) internal pure returns (uint8) {
        return uint8(status);
    }

    function convertToSwapStatus(uint8 status) internal pure returns (ICrossChainManager.SwapStatus) {
        require(status <= uint8(ICrossChainManager.SwapStatus.Recovered), "Invalid swap status");
        return ICrossChainManager.SwapStatus(status);
    }
}