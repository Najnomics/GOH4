// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IGasPriceOracle} from "../interfaces/IGasPriceOracle.sol";
import {Constants} from "../utils/Constants.sol";
import {Errors} from "../utils/Errors.sol";
import {Events} from "../utils/Events.sol";
import {ChainUtils} from "../libraries/ChainUtils.sol";
import {GasCalculations} from "../libraries/GasCalculations.sol";

/// @title Gas Price Oracle for multi-chain gas price tracking
contract GasPriceOracle is IGasPriceOracle, Ownable {
    using ChainUtils for uint256;
    using GasCalculations for uint256;

    // Storage
    mapping(uint256 => GasPrice) private gasPrices;
    mapping(uint256 => AggregatorV3Interface) private ethUsdPriceFeeds;
    mapping(uint256 => uint256[]) private gasPriceHistory;
    
    address public keeper;
    uint256 public stalenessThreshold = Constants.GAS_PRICE_STALENESS_THRESHOLD;
    
    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) {
            revert Errors.UnauthorizedKeeper();
        }
        _;
    }

    constructor(address initialOwner, address initialKeeper) Ownable(initialOwner) {
        keeper = initialKeeper;
        _initializeSupportedChains();
    }

    /// @inheritdoc IGasPriceOracle
    function getGasPrice(uint256 chainId) external view override returns (uint256 gasPrice, uint256 timestamp) {
        chainId.validateChainId();
        GasPrice memory price = gasPrices[chainId];
        
        if (!price.isValid) {
            revert Errors.StaleGasPrice();
        }
        
        return (price.price, price.timestamp);
    }

    /// @inheritdoc IGasPriceOracle
    function getGasPriceUSD(uint256 chainId) external view override returns (uint256 gasPriceUSD) {
        (uint256 gasPrice,) = this.getGasPrice(chainId);
        
        // Get ETH price in USD
        AggregatorV3Interface priceFeed = ethUsdPriceFeeds[chainId];
        if (address(priceFeed) == address(0)) {
            revert Errors.InvalidPriceFeed();
        }
        
        (, int256 ethPriceUSD, , uint256 updatedAt,) = priceFeed.latestRoundData();
        
        if (block.timestamp - updatedAt > stalenessThreshold) {
            revert Errors.PriceFeedStale();
        }
        
        // Convert gas price from gwei to USD
        // gasPrice (gwei) * ethPriceUSD / 1e9 / 1e8 * 1e18 = USD with 18 decimals
        gasPriceUSD = (gasPrice * uint256(ethPriceUSD) * 1e18) / (1e9 * 1e8);
    }

    /// @inheritdoc IGasPriceOracle
    function updateGasPrices(uint256[] calldata chainIds, uint256[] calldata gasPricesArray) external override onlyKeeper {
        if (chainIds.length != gasPricesArray.length) {
            revert Errors.ArrayLengthMismatch();
        }
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            uint256 gasPrice = gasPricesArray[i];
            
            chainId.validateChainId();
            
            if (!gasPrice.validateGasPrice()) {
                revert Errors.InvalidGasPrice();
            }
            
            gasPrices[chainId] = GasPrice({
                price: gasPrice,
                timestamp: block.timestamp,
                isValid: true
            });
            
            // Store historical data (keep last 24 entries)
            uint256[] storage history = gasPriceHistory[chainId];
            if (history.length >= 24) {
                // Remove oldest entry
                for (uint256 j = 0; j < 23; j++) {
                    history[j] = history[j + 1];
                }
                history[23] = gasPrice;
            } else {
                history.push(gasPrice);
            }
            
            emit Events.GasPriceUpdated(chainId, gasPrice, block.timestamp);
        }
    }

    /// @inheritdoc IGasPriceOracle
    function getGasPriceTrend(uint256 chainId, uint256 timeWindow) external view override returns (GasTrend memory trend) {
        chainId.validateChainId();
        
        uint256[] storage history = gasPriceHistory[chainId];
        if (history.length == 0) {
            return GasTrend({
                averagePrice: 0,
                minPrice: 0,
                maxPrice: 0,
                volatility: 0,
                isIncreasing: false
            });
        }
        
        uint256 windowSize = timeWindow > history.length ? history.length : timeWindow;
        uint256 startIndex = history.length - windowSize;
        
        uint256 sum = 0;
        uint256 min = type(uint256).max;
        uint256 max = 0;
        
        for (uint256 i = startIndex; i < history.length; i++) {
            uint256 price = history[i];
            sum += price;
            if (price < min) min = price;
            if (price > max) max = price;
        }
        
        uint256 average = sum / windowSize;
        
        // Calculate volatility (simple standard deviation approximation)
        uint256 volatility = max > min ? ((max - min) * Constants.BASIS_POINTS_DENOMINATOR) / average : 0;
        
        // Determine trend direction
        bool isIncreasing = false;
        if (history.length >= 2) {
            isIncreasing = history[history.length - 1] > history[history.length - 2];
        }
        
        return GasTrend({
            averagePrice: average,
            minPrice: min,
            maxPrice: max,
            volatility: volatility,
            isIncreasing: isIncreasing
        });
    }

    /// @inheritdoc IGasPriceOracle
    function isGasPriceStale(uint256 chainId) external view override returns (bool) {
        GasPrice memory price = gasPrices[chainId];
        return !price.isValid || (block.timestamp - price.timestamp) > stalenessThreshold;
    }

    /// @inheritdoc IGasPriceOracle
    function getLastUpdateTime(uint256 chainId) external view override returns (uint256) {
        return gasPrices[chainId].timestamp;
    }

    /// @inheritdoc IGasPriceOracle
    function addChain(uint256 chainId, address ethUsdPriceFeed) external override onlyOwner {
        chainId.validateChainId();
        if (ethUsdPriceFeed == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        ethUsdPriceFeeds[chainId] = AggregatorV3Interface(ethUsdPriceFeed);
        
        emit Events.GasPriceOracleConfigured(
            _getSingleChainArray(chainId),
            _getSingleAddressArray(ethUsdPriceFeed)
        );
    }

    /// @inheritdoc IGasPriceOracle
    function updateKeeper(address newKeeper) external override onlyOwner {
        if (newKeeper == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        address oldKeeper = keeper;
        keeper = newKeeper;
        
        emit Events.KeeperUpdated(oldKeeper, newKeeper);
    }

    /// @inheritdoc IGasPriceOracle
    function updateStalenessThreshold(uint256 newThreshold) external override onlyOwner {
        stalenessThreshold = newThreshold;
    }

    /// @inheritdoc IGasPriceOracle
    function validateGasPrice(uint256 chainId, uint256 gasPrice) external view override returns (bool) {
        return chainId.isSupportedChain() && gasPrice.validateGasPrice();
    }

    /// @inheritdoc IGasPriceOracle
    function getSupportedChains() external pure override returns (uint256[] memory) {
        return ChainUtils.getSupportedChains();
    }

    function _initializeSupportedChains() private {
        // Initialize with mainnet Chainlink ETH/USD price feeds
        ethUsdPriceFeeds[Constants.ETHEREUM_CHAIN_ID] = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        ethUsdPriceFeeds[Constants.ARBITRUM_CHAIN_ID] = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
        ethUsdPriceFeeds[Constants.OPTIMISM_CHAIN_ID] = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        ethUsdPriceFeeds[Constants.POLYGON_CHAIN_ID] = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945);
        ethUsdPriceFeeds[Constants.BASE_CHAIN_ID] = AggregatorV3Interface(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
    }

    function _getSingleChainArray(uint256 chainId) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = chainId;
        return array;
    }

    function _getSingleAddressArray(address addr) private pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = addr;
        return array;
    }
}