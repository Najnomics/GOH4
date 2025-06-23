// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Interface for Gas Price Oracle
interface IGasPriceOracle {
    struct GasPrice {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    struct GasTrend {
        uint256 averagePrice;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 volatility;
        bool isIncreasing;
    }

    // Core oracle functions
    function getGasPrice(uint256 chainId) external view returns (uint256 gasPrice, uint256 timestamp);
    function getGasPriceUSD(uint256 chainId) external view returns (uint256 gasPriceUSD);
    function updateGasPrices(uint256[] calldata chainIds, uint256[] calldata gasPrices) external;

    // Analytics functions
    function getGasPriceTrend(uint256 chainId, uint256 timeWindow) external view returns (GasTrend memory);
    function isGasPriceStale(uint256 chainId) external view returns (bool);
    function getLastUpdateTime(uint256 chainId) external view returns (uint256);

    // Configuration functions
    function addChain(uint256 chainId, address ethUsdPriceFeed) external;
    function updateKeeper(address newKeeper) external;
    function updateStalenessThreshold(uint256 newThreshold) external;

    // Validation functions
    function validateGasPrice(uint256 chainId, uint256 gasPrice) external view returns (bool);
    function getSupportedChains() external view returns (uint256[] memory);
}