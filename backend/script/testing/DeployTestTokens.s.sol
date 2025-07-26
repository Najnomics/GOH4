// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**6); // 1M USDC with 6 decimals
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
        _mint(msg.sender, 10000 * 10**18); // 10K WETH
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}

contract MockDAI is ERC20 {
    constructor() ERC20("Dai Stablecoin", "DAI") {
        _mint(msg.sender, 1000000 * 10**18); // 1M DAI
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeployTestTokens is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy test tokens
        MockUSDC usdc = new MockUSDC();
        MockWETH weth = new MockWETH();
        MockDAI dai = new MockDAI();

        console.log("=== TEST TOKENS DEPLOYED ===");
        console.log("MockUSDC deployed to:", address(usdc));
        console.log("MockWETH deployed to:", address(weth));
        console.log("MockDAI deployed to:", address(dai));
        console.log("Deployer:", deployer);

        // Mint additional tokens to deployer for testing
        usdc.mint(deployer, 500000 * 10**6); // 500K USDC
        weth.mint(deployer, 5000 * 10**18); // 5K WETH
        dai.mint(deployer, 500000 * 10**18); // 500K DAI

        console.log("=== BALANCES ===");
        console.log("USDC balance:", usdc.balanceOf(deployer) / 10**6, "USDC");
        console.log("WETH balance:", weth.balanceOf(deployer) / 10**18, "WETH");
        console.log("DAI balance:", dai.balanceOf(deployer) / 10**18, "DAI");

        vm.stopBroadcast();
    }
} 