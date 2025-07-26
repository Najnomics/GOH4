// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

// Re-export MockERC20 from solmate for convenience
// This provides a simple mock ERC20 implementation for testing
contract TestMockERC20 is MockERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) MockERC20(name, symbol, decimals) {}
}