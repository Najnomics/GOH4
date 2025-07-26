// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Gas Optimization Storage layout
library GasOptimizationStorage {
    struct Layout {
        // Packed struct for user preferences (32 bytes)
        mapping(address => UserPreferences) userPreferences;
        
        // Packed struct for system configuration
        SystemConfiguration systemConfig;
        
        // Analytics data
        mapping(address => UserAnalytics) userAnalytics;
        GlobalAnalytics globalAnalytics;
        
        // Emergency controls
        bool isPaused;
        uint256 pausedAt;
        
        // Upgrade storage
        uint256[50] __gap; // Reserved for future upgrades
    }

    struct UserPreferences {
        uint96 minSavingsThresholdBPS;      // 96 bits
        uint96 minAbsoluteSavingsUSD;       // 96 bits  
        uint64 maxAcceptableBridgeTime;     // 64 bits
        // Total: 256 bits (1 slot)
        
        bool enableCrossChainOptimization;  // 8 bits
        bool enableUSDDisplay;              // 8 bits
        uint240 reserved;                   // 240 bits reserved
        // Total: 256 bits (1 slot)
    }

    struct SystemConfiguration {
        uint96 minSavingsThresholdBPS;      // 96 bits
        uint96 minAbsoluteSavingsUSD;       // 96 bits
        uint64 maxBridgeTime;               // 64 bits
        // Total: 256 bits (1 slot)
        
        uint64 lastUpdated;                 // 64 bits
        uint64 updateDelay;                 // 64 bits
        uint128 reserved;                   // 128 bits reserved
        // Total: 256 bits (1 slot)
    }

    struct UserAnalytics {
        uint128 totalSavingsUSD;            // 128 bits
        uint64 totalSwapsOptimized;         // 64 bits
        uint64 lastSwapTimestamp;           // 64 bits
        // Total: 256 bits (1 slot)
    }

    struct GlobalAnalytics {
        uint128 totalSystemSavingsUSD;      // 128 bits
        uint64 totalSwapsOptimized;         // 64 bits
        uint64 lastUpdateTimestamp;         // 64 bits
        // Total: 256 bits (1 slot)
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("gasoptimization.storage.layout");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}