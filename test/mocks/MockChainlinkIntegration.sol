// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IChainlinkAggregator} from "../../src/interfaces/external/IChainlinkAggregator.sol";

/// @title Mock Chainlink Integration for testing
contract MockChainlinkIntegration is IChainlinkAggregator {
    mapping(address => uint256) private _tokenPrices;
    mapping(address => PriceFeedData) private _priceFeeds;
    uint256 private _ethPriceUSD = 2000e18; // $2000 ETH

    constructor() {
        // Set default token prices for testing
        _tokenPrices[address(0x1)] = 1e18; // $1 per token
        _tokenPrices[address(0xa0b86A33E6C4B4C2Cc6c1c4CdbBD0d8C7B4e5d2A)] = 1e18; // USDC = $1
    }

    function setTokenPrice(address token, uint256 priceUSD) external {
        _tokenPrices[token] = priceUSD;
    }

    function setEthPrice(uint256 priceUSD) external {
        _ethPriceUSD = priceUSD;
    }

    function getTokenPriceUSD(address token) external view override returns (PriceData memory) {
        uint256 price = _tokenPrices[token];
        if (price == 0) price = 1e18; // Default $1
        
        return PriceData({
            price: price,
            timestamp: block.timestamp,
            roundId: 1,
            isValid: true
        });
    }

    function getETHPriceUSD() external view override returns (PriceData memory) {
        return PriceData({
            price: _ethPriceUSD,
            timestamp: block.timestamp,
            roundId: 1,
            isValid: true
        });
    }

    function getMultipleTokenPricesUSD(address[] calldata tokens) 
        external view override returns (PriceData[] memory prices) {
        prices = new PriceData[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 price = _tokenPrices[tokens[i]];
            if (price == 0) price = 1e18;
            prices[i] = PriceData({
                price: price,
                timestamp: block.timestamp,
                roundId: 1,
                isValid: true
            });
        }
    }

    function addPriceFeed(address token, address priceFeed, uint256 heartbeat) external override {
        _priceFeeds[token] = PriceFeedData({
            feedAddress: priceFeed,
            heartbeat: heartbeat,
            decimals: 18,
            isActive: true
        });
        emit PriceFeedAdded(token, priceFeed, heartbeat);
    }

    function updatePriceFeed(address token, address newPriceFeed) external override {
        address oldFeed = _priceFeeds[token].feedAddress;
        _priceFeeds[token].feedAddress = newPriceFeed;
        emit PriceFeedUpdated(token, oldFeed, newPriceFeed);
    }

    function removePriceFeed(address token) external override {
        address oldFeed = _priceFeeds[token].feedAddress;
        delete _priceFeeds[token];
        emit PriceFeedRemoved(token, oldFeed);
    }

    function getPriceFeedData(address token) external view override returns (PriceFeedData memory) {
        return _priceFeeds[token];
    }

    function isPriceFeedValid(address token) external view override returns (bool) {
        return _priceFeeds[token].feedAddress != address(0) && _priceFeeds[token].isActive;
    }

    function isPriceStale(address token, uint256 maxAge) external view override returns (bool) {
        return block.timestamp - block.timestamp > maxAge; // Always false for mock
    }

    function convertToUSD(address token, uint256 amount) external view override returns (uint256) {
        uint256 price = _tokenPrices[token];
        if (price == 0) price = 1e18; // Default $1
        
        return (amount * price) / 1e18;
    }

    function convertFromUSD(address token, uint256 usdAmount) external view override returns (uint256) {
        uint256 price = _tokenPrices[token];
        if (price == 0) price = 1e18; // Default $1
        
        return (usdAmount * 1e18) / price;
    }

    function getGasPriceETH(uint256 /*chainId*/) external pure override returns (uint256 gasPrice) {
        return 50e9; // 50 gwei default
    }

    function calculateGasCostUSD(uint256 gasUsed, uint256 gasPrice, uint256 /*chainId*/) 
        external view override returns (uint256) {
        uint256 gasCostWei = gasUsed * gasPrice;
        uint256 gasCostETH = gasCostWei; // Simplified for testing
        return (gasCostETH * _ethPriceUSD) / 1e18;
    }
}