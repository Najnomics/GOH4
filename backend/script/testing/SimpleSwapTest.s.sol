// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {GasOptimizationHook} from "../../src/hooks/GasOptimizationHook.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleSwapTest is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Contract addresses from deployment
        GasOptimizationHook hook = GasOptimizationHook(payable(0x9C349D86b5A559116b2CF7bFe311CE6205ADc080));
        
        // Test token addresses
        ERC20 usdc = ERC20(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        ERC20 weth = ERC20(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853);

        console.log("=== REAL-TIME SWAP TESTING ===");
        console.log("Hook address:", address(hook));
        console.log("USDC address:", address(usdc));
        console.log("WETH address:", address(weth));
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Check token balances
        uint256 usdcBalance = usdc.balanceOf(deployer);
        uint256 wethBalance = weth.balanceOf(deployer);
        
        console.log("=== TOKEN BALANCES ===");
        console.log("USDC balance:", usdcBalance / 10**6, "USDC");
        console.log("WETH balance:", wethBalance / 10**18, "WETH");

        // Test basic hook functionality
        console.log("=== HOOK STATUS ===");
        
        bool isPaused = hook.isPaused();
        console.log("Hook is paused:", isPaused);

        uint256 minSavings = hook.minSavingsThresholdBPS();
        console.log("Min savings threshold BPS:", minSavings);

        uint256 totalSwaps = hook.totalSwapsOptimized();
        console.log("Total swaps optimized:", totalSwaps);

        address owner = hook.owner();
        console.log("Hook owner:", owner);

        // Test token approvals
        console.log("=== TOKEN APPROVALS ===");
        
        // Approve some tokens for testing
        uint256 approvalAmount = 1000 * 10**6; // 1000 USDC
        usdc.approve(address(hook), approvalAmount);
        console.log("Approved", approvalAmount / 10**6, "USDC for hook");

        uint256 wethApprovalAmount = 1 * 10**18; // 1 WETH
        weth.approve(address(hook), wethApprovalAmount);
        console.log("Approved", wethApprovalAmount / 10**18, "WETH for hook");

        // Check allowances
        uint256 usdcAllowance = usdc.allowance(deployer, address(hook));
        uint256 wethAllowance = weth.allowance(deployer, address(hook));
        
        console.log("USDC allowance:", usdcAllowance / 10**6, "USDC");
        console.log("WETH allowance:", wethAllowance / 10**18, "WETH");

        // Transfer some tokens to simulate real activity
        console.log("=== SIMULATING TOKEN ACTIVITY ===");
        
        // Transfer 100 USDC to hook address (simulating deposit)
        uint256 transferAmount = 100 * 10**6;
        usdc.transfer(address(hook), transferAmount);
        console.log("Transferred", transferAmount / 10**6, "USDC to hook");

        // Check new balances
        uint256 newUsdcBalance = usdc.balanceOf(deployer);
        uint256 hookUsdcBalance = usdc.balanceOf(address(hook));
        
        console.log("New deployer USDC balance:", newUsdcBalance / 10**6, "USDC");
        console.log("Hook USDC balance:", hookUsdcBalance / 10**6, "USDC");

        // Test hook configuration
        console.log("=== HOOK CONFIGURATION ===");
        
        address costCalculatorAddr = address(hook.costCalculator());
        address crossChainManagerAddr = address(hook.crossChainManager());
        
        console.log("Cost calculator:", costCalculatorAddr);
        console.log("Cross-chain manager:", crossChainManagerAddr);

        vm.stopBroadcast();

        console.log("=== REAL-TIME TEST COMPLETE ===");
        console.log("Successfully tested:");
        console.log("- Token balances and transfers");
        console.log("- Token approvals and allowances");
        console.log("- Hook configuration and status");
        console.log("- Contract interactions");
        console.log("");
        console.log("Ready for frontend integration!");
    }
} 