// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Mock Price Feed for testing
contract MockPriceFeed is AggregatorV3Interface {
    uint8 public constant decimals = 8;
    string public description = "ETH / USD";
    uint256 public constant version = 1;
    
    int256 private _latestAnswer = 2000e8; // $2000 with 8 decimals
    uint256 private _latestTimestamp = block.timestamp;
    uint80 private _latestRoundId = 1;
    
    function setLatestAnswer(int256 answer) external {
        _latestAnswer = answer;
        _latestTimestamp = block.timestamp;
        _latestRoundId++;
    }
    
    function getRoundData(uint80 /*_roundId*/) external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (_latestRoundId, _latestAnswer, _latestTimestamp, _latestTimestamp, _latestRoundId);
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (_latestRoundId, _latestAnswer, _latestTimestamp, _latestTimestamp, _latestRoundId);
    }
}