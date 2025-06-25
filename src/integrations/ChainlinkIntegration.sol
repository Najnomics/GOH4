// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IChainlinkAggregator} from "../interfaces/external/IChainlinkAggregator.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {ChainUtils} from "../libraries/ChainUtils.sol";

/// @title Chainlink Integration for USD Price Feeds and Gas Cost Calculations
contract ChainlinkIntegration is IChainlinkAggregator, Ownable {
    using ChainUtils for uint256;

    // Mapping from token address to price feed data
    mapping(address => PriceFeedData) public priceFeeds;
    
    // Mapping from chainId to ETH price feed (for gas cost calculations)
    mapping(uint256 => address) public ethPriceFeeds;
    
    // Special addresses for native tokens
    address public constant ETH_ADDRESS = address(0);
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Default heartbeat for price feeds (8 hours)
    uint256 public constant DEFAULT_HEARTBEAT = 8 hours;
    
    // Maximum age for price data (1 hour)
    uint256 public constant MAX_PRICE_AGE = 1 hours;

    constructor(address initialOwner) Ownable(initialOwner) {
        _initializeMainnetPriceFeeds();
    }

    /// @inheritdoc IChainlinkAggregator
    function getTokenPriceUSD(address token) external view override returns (PriceData memory) {
        // Handle ETH/WETH special case
        if (token == ETH_ADDRESS || token == WETH_ADDRESS) {
            return getETHPriceUSD();
        }

        PriceFeedData memory feedData = priceFeeds[token];
        if (feedData.feedAddress == address(0)) {
            revert UnsupportedToken(token);
        }

        return _getPriceFromFeed(feedData.feedAddress, token);
    }

    /// @inheritdoc IChainlinkAggregator
    function getETHPriceUSD() public view override returns (PriceData memory) {
        address ethFeed = ethPriceFeeds[block.chainid];
        if (ethFeed == address(0)) {
            // Fallback to mainnet ETH price feed
            ethFeed = ethPriceFeeds[Constants.ETHEREUM_CHAIN_ID];
        }
        
        if (ethFeed == address(0)) {
            revert InvalidPriceFeed(ETH_ADDRESS);
        }

        return _getPriceFromFeed(ethFeed, ETH_ADDRESS);
    }

    /// @inheritdoc IChainlinkAggregator
    function getGasPriceETH(uint256 chainId) external view override returns (uint256 gasPrice) {
        // This would integrate with gas price oracles
        // For now, return estimated gas prices
        if (chainId == Constants.ETHEREUM_CHAIN_ID) {
            return 30 gwei; // Mainnet
        } else if (chainId == Constants.ARBITRUM_CHAIN_ID) {
            return 0.1 gwei; // Arbitrum
        } else if (chainId == Constants.OPTIMISM_CHAIN_ID) {
            return 0.001 gwei; // Optimism
        } else if (chainId == Constants.POLYGON_CHAIN_ID) {
            return 30 gwei; // Polygon
        } else if (chainId == Constants.BASE_CHAIN_ID) {
            return 0.001 gwei; // Base
        }
        
        return 10 gwei; // Default
    }

    /// @inheritdoc IChainlinkAggregator
    function getMultipleTokenPricesUSD(address[] calldata tokens) 
        external 
        view 
        override 
        returns (PriceData[] memory prices) 
    {
        prices = new PriceData[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            prices[i] = this.getTokenPriceUSD(tokens[i]);
        }
    }

    /// @inheritdoc IChainlinkAggregator
    function addPriceFeed(address token, address priceFeed, uint256 heartbeat) external override onlyOwner {
        if (priceFeed == address(0)) {
            revert InvalidPriceFeed(token);
        }
        
        if (heartbeat == 0) {
            revert InvalidHeartbeat(heartbeat);
        }

        // Validate the price feed by attempting to get latest data
        try AggregatorV3Interface(priceFeed).latestRoundData() returns (
            uint80, int256 price, uint256, uint256, uint80
        ) {
            if (price <= 0) {
                revert ZeroPrice(token);
            }
        } catch {
            revert InvalidPriceFeed(token);
        }

        uint8 decimals = AggregatorV3Interface(priceFeed).decimals();

        priceFeeds[token] = PriceFeedData({
            feedAddress: priceFeed,
            heartbeat: heartbeat,
            decimals: decimals,
            isActive: true
        });

        emit PriceFeedAdded(token, priceFeed, heartbeat);
    }

    /// @inheritdoc IChainlinkAggregator
    function updatePriceFeed(address token, address newPriceFeed) external override onlyOwner {
        PriceFeedData storage feedData = priceFeeds[token];
        address oldFeed = feedData.feedAddress;
        
        if (oldFeed == address(0)) {
            revert UnsupportedToken(token);
        }

        feedData.feedAddress = newPriceFeed;
        feedData.decimals = AggregatorV3Interface(newPriceFeed).decimals();

        emit PriceFeedUpdated(token, oldFeed, newPriceFeed);
    }

    /// @inheritdoc IChainlinkAggregator
    function removePriceFeed(address token) external override onlyOwner {
        PriceFeedData storage feedData = priceFeeds[token];
        address oldFeed = feedData.feedAddress;
        
        if (oldFeed == address(0)) {
            revert UnsupportedToken(token);
        }

        feedData.isActive = false;
        feedData.feedAddress = address(0);

        emit PriceFeedRemoved(token, oldFeed);
    }

    /// @inheritdoc IChainlinkAggregator
    function getPriceFeedData(address token) external view override returns (PriceFeedData memory) {
        return priceFeeds[token];
    }

    /// @inheritdoc IChainlinkAggregator
    function isPriceFeedValid(address token) external view override returns (bool) {
        PriceFeedData memory feedData = priceFeeds[token];
        return feedData.feedAddress != address(0) && feedData.isActive;
    }

    /// @inheritdoc IChainlinkAggregator
    function isPriceStale(address token, uint256 maxAge) external view override returns (bool) {
        PriceFeedData memory feedData = priceFeeds[token];
        if (feedData.feedAddress == address(0)) {
            return true;
        }

        try AggregatorV3Interface(feedData.feedAddress).latestRoundData() returns (
            uint80, int256, uint256, uint256 updatedAt, uint80
        ) {
            return block.timestamp - updatedAt > maxAge;
        } catch {
            return true;
        }
    }

    /// @inheritdoc IChainlinkAggregator
    function convertToUSD(address token, uint256 amount) external view override returns (uint256) {
        PriceData memory priceData = this.getTokenPriceUSD(token);
        if (!priceData.isValid) {
            revert InvalidPriceFeed(token);
        }

        // Price is in USD with 8 decimals, amount might have different decimals
        // Assuming 18 decimals for most tokens
        return (amount * priceData.price) / 1e8;
    }

    /// @inheritdoc IChainlinkAggregator
    function convertFromUSD(address token, uint256 usdAmount) external view override returns (uint256) {
        PriceData memory priceData = this.getTokenPriceUSD(token);
        if (!priceData.isValid) {
            revert InvalidPriceFeed(token);
        }

        // Convert USD amount back to token amount
        return (usdAmount * 1e8) / priceData.price;
    }

    /// @inheritdoc IChainlinkAggregator
    function calculateGasCostUSD(uint256 gasUsed, uint256 gasPrice, uint256 chainId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        // Calculate gas cost in ETH
        uint256 gasCostWei = gasUsed * gasPrice;
        
        // Get ETH price
        PriceData memory ethPrice = this.getETHPriceUSD();
        if (!ethPrice.isValid) {
            revert InvalidPriceFeed(ETH_ADDRESS);
        }

        // Convert to USD (ETH has 18 decimals, price has 8 decimals)
        return (gasCostWei * ethPrice.price) / 1e26; // 1e18 + 1e8 = 1e26
    }

    // Admin functions
    function updateETHPriceFeed(uint256 chainId, address priceFeed) external onlyOwner {
        ethPriceFeeds[chainId] = priceFeed;
    }

    function _getPriceFromFeed(address feedAddress, address token) private view returns (PriceData memory) {
        try AggregatorV3Interface(feedAddress).latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (price <= 0) {
                return PriceData({
                    price: 0,
                    timestamp: updatedAt,
                    roundId: roundId,
                    isValid: false
                });
            }

            // Check if price is stale
            bool isStale = block.timestamp - updatedAt > MAX_PRICE_AGE;

            emit PriceDataQueried(token, uint256(price), updatedAt);

            return PriceData({
                price: uint256(price),
                timestamp: updatedAt,
                roundId: roundId,
                isValid: !isStale
            });
        } catch {
            return PriceData({
                price: 0,
                timestamp: 0,
                roundId: 0,
                isValid: false
            });
        }
    }

    function _initializeMainnetPriceFeeds() private {
        // Ethereum Mainnet price feeds
        ethPriceFeeds[Constants.ETHEREUM_CHAIN_ID] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD

        // Add common token price feeds
        priceFeeds[0xa0b86a33E6C4b4c2CC6C1C4CdBbD0D8C7b4e5d2A] = PriceFeedData({ // USDC
            feedAddress: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
            heartbeat: DEFAULT_HEARTBEAT,
            decimals: 8,
            isActive: true
        });

        priceFeeds[0x514910771AF9Ca656af840dff83E8264EcF986CA] = PriceFeedData({ // LINK
            feedAddress: 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c,
            heartbeat: DEFAULT_HEARTBEAT,
            decimals: 8,
            isActive: true
        });

        priceFeeds[0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599] = PriceFeedData({ // WBTC
            feedAddress: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            heartbeat: DEFAULT_HEARTBEAT,
            decimals: 8,
            isActive: true
        });

        priceFeeds[0xdAC17F958D2ee523a2206206994597C13D831ec7] = PriceFeedData({ // USDT
            feedAddress: 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D,
            heartbeat: DEFAULT_HEARTBEAT,
            decimals: 8,
            isActive: true
        });
    }
}