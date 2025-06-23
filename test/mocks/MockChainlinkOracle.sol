// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Mock Chainlink Price Feed for testing
contract MockChainlinkOracle is AggregatorV3Interface {
    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint8 private _decimals;
    string private _description;
    
    constructor(
        int256 initialPrice,
        uint8 decimalsValue,
        string memory desc
    ) {
        _price = initialPrice;
        _decimals = decimalsValue;
        _description = desc;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }
    
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    
    function description() external view override returns (string memory) {
        return _description;
    }
    
    function version() external pure override returns (uint256) {
        return 4;
    }
    
    function getRoundData(uint80 roundId) external view override returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (roundId, _price, _updatedAt, _updatedAt, roundId);
    }
    
    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
    
    // Test helper functions
    function updatePrice(int256 newPrice) external {
        _price = newPrice;
        _updatedAt = block.timestamp;
        _roundId++;
    }
    
    function setStalePrice(uint256 staleness) external {
        _updatedAt = block.timestamp - staleness;
    }
    
    function getPrice() external view returns (int256) {
        return _price;
    }
}