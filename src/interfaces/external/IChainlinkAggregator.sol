// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Chainlink Aggregator Interface for Gas Optimization Hook
interface IChainlinkAggregator {
    struct PriceFeedData {
        address feedAddress;
        uint256 heartbeat;
        uint8 decimals;
        bool isActive;
    }

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint80 roundId;
        bool isValid;
    }

    // Core price feed functions
    function getTokenPriceUSD(address token) external view returns (PriceData memory);
    
    function getETHPriceUSD() external view returns (PriceData memory);
    
    function getGasPriceETH(uint256 chainId) external view returns (uint256 gasPrice);

    // Multi-token price functions
    function getMultipleTokenPricesUSD(address[] calldata tokens) 
        external view returns (PriceData[] memory prices);

    // Price feed management
    function addPriceFeed(address token, address priceFeed, uint256 heartbeat) external;
    
    function updatePriceFeed(address token, address newPriceFeed) external;
    
    function removePriceFeed(address token) external;

    function getPriceFeedData(address token) external view returns (PriceFeedData memory);

    // Validation functions
    function isPriceFeedValid(address token) external view returns (bool);
    
    function isPriceStale(address token, uint256 maxAge) external view returns (bool);

    // Conversion utilities
    function convertToUSD(address token, uint256 amount) external view returns (uint256);
    
    function convertFromUSD(address token, uint256 usdAmount) external view returns (uint256);

    // Gas cost calculations
    function calculateGasCostUSD(uint256 gasUsed, uint256 gasPrice, uint256 chainId) 
        external view returns (uint256);

    // Events
    event PriceFeedAdded(address indexed token, address indexed priceFeed, uint256 heartbeat);
    event PriceFeedUpdated(address indexed token, address indexed oldFeed, address indexed newFeed);
    event PriceFeedRemoved(address indexed token, address indexed priceFeed);
    event PriceDataQueried(address indexed token, uint256 price, uint256 timestamp);

    // Errors
    error InvalidPriceFeed(address token);
    error StalePriceData(address token, uint256 lastUpdate);
    error UnsupportedToken(address token);
    error InvalidHeartbeat(uint256 heartbeat);
    error ZeroPrice(address token);
}