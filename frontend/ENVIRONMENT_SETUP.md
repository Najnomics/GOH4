# Environment Setup Guide

This guide explains how to set up the environment variables for the GasOpt frontend to connect to the blockchain networks.

## Quick Setup

1. Create a `.env` file in the `frontend` directory
2. Copy the following content and update with your values:

```bash
# Frontend Environment Variables

# WalletConnect Project ID (get this from https://cloud.walletconnect.com/)
VITE_WALLET_CONNECT_PROJECT_ID=your_walletconnect_project_id

# Testnet RPC URLs (Alchemy recommended)
VITE_ETHEREUM_SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
VITE_OPTIMISM_SEPOLIA_RPC=https://opt-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
VITE_ARBITRUM_SEPOLIA_RPC=https://arb-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
VITE_BASE_SEPOLIA_RPC=https://base-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
VITE_UNICHAIN_SEPOLIA_RPC=https://unichain-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
VITE_POLYGON_AMOY_RPC=https://polygon-amoy.g.alchemy.com/v2/YOUR_ALCHEMY_KEY

# Block Explorer API Keys (get from respective block explorers)
VITE_ETHERSCAN_API_KEY=your_etherscan_api_key
VITE_ARBISCAN_API_KEY=your_arbiscan_api_key
VITE_OPTIMISTIC_ETHERSCAN_API_KEY=your_optimistic_etherscan_api_key
VITE_POLYGONSCAN_API_KEY=your_polygonscan_api_key
VITE_BASESCAN_API_KEY=your_basescan_api_key

# Contract Addresses (will be updated after deployment)
VITE_GAS_OPTIMIZATION_HOOK_ADDRESS=
VITE_COST_CALCULATOR_ADDRESS=
VITE_GAS_PRICE_ORACLE_ADDRESS=
VITE_CROSS_CHAIN_MANAGER_ADDRESS=
```

## Required Services

### 1. WalletConnect
- Go to [WalletConnect Cloud](https://cloud.walletconnect.com/)
- Create a new project
- Copy the Project ID to `VITE_WALLET_CONNECT_PROJECT_ID`

### 2. Alchemy (Recommended for RPC URLs)
- Go to [Alchemy](https://www.alchemy.com/)
- Create an account and get API keys
- Use the HTTP URLs for each network

### 3. Block Explorer API Keys
- **Etherscan**: [Get API Key](https://etherscan.io/apis)
- **Arbiscan**: [Get API Key](https://arbiscan.io/apis)
- **Optimistic Etherscan**: [Get API Key](https://optimistic.etherscan.io/apis)
- **Polygonscan**: [Get API Key](https://polygonscan.com/apis)
- **Basescan**: [Get API Key](https://basescan.org/apis)

## Alternative RPC Providers

If you don't want to use Alchemy, you can use these public RPC URLs:

```bash
# Public RPC URLs (less reliable, not recommended for production)
VITE_ETHEREUM_SEPOLIA_RPC=https://rpc.sepolia.org
VITE_OPTIMISM_SEPOLIA_RPC=https://sepolia.optimism.io
VITE_ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
VITE_BASE_SEPOLIA_RPC=https://sepolia.base.org
VITE_POLYGON_AMOY_RPC=https://rpc-amoy.polygon.technology
```

## Contract Addresses

After deploying your smart contracts, update these addresses:

```bash
VITE_GAS_OPTIMIZATION_HOOK_ADDRESS=0x...
VITE_COST_CALCULATOR_ADDRESS=0x...
VITE_GAS_PRICE_ORACLE_ADDRESS=0x...
VITE_CROSS_CHAIN_MANAGER_ADDRESS=0x...
```

## Testing the Setup

1. Start the development server:
   ```bash
   npm run dev
   ```

2. Open the browser and connect a wallet
3. Try switching between different networks
4. Check the browser console for any connection errors

## Troubleshooting

### Common Issues

1. **"Failed to connect to RPC"**
   - Check your RPC URLs are correct
   - Ensure your Alchemy API key is valid
   - Try using a different RPC provider

2. **"WalletConnect project ID not found"**
   - Make sure `VITE_WALLET_CONNECT_PROJECT_ID` is set
   - Verify the project ID is correct

3. **"Contract not found"**
   - Ensure contract addresses are deployed and correct
   - Check that you're on the right network

### Network Chain IDs

- Ethereum Sepolia: 11155111
- Optimism Sepolia: 11155420
- Arbitrum Sepolia: 421614
- Base Sepolia: 84532
- Polygon Amoy: 80002

## Security Notes

- Never commit your `.env` file to version control
- Keep your API keys secure
- Use environment-specific keys for development/production
- Consider using a secrets management service for production 