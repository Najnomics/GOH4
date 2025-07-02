// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Constants {
    // Chain IDs
    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    uint256 constant OPTIMISM_CHAIN_ID = 10;
    uint256 constant POLYGON_CHAIN_ID = 137;
    uint256 constant BASE_CHAIN_ID = 8453;

    // Gas constants
    uint256 constant MAX_GAS_PRICE = 1000 gwei;
    uint256 constant MIN_GAS_PRICE = 1 gwei;
    uint256 constant GAS_PRICE_STALENESS_THRESHOLD = 600; // 10 minutes
    uint256 constant GAS_ESTIMATION_MULTIPLIER = 12000; // 1.2x (120% in basis points)

    // Basis points constants
    uint256 constant BASIS_POINTS_DENOMINATOR = 10000;
    uint256 constant DEFAULT_MIN_SAVINGS_BPS = 500; // 5%
    uint256 constant DEFAULT_MIN_ABSOLUTE_SAVINGS_USD = 10e18; // $10 USD

    // Bridge constants
    uint256 constant MAX_BRIDGE_TIME = 1800; // 30 minutes
    uint256 constant BRIDGE_SAFETY_MARGIN_BPS = 200; // 2%

    // USD decimals
    uint256 constant USD_DECIMALS = 18;
    uint256 constant CHAINLINK_PRICE_DECIMALS = 8;
}