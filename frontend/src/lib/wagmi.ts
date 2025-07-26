import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import {
    metaMaskWallet,
    injectedWallet,
    rainbowWallet,
    walletConnectWallet,
    coinbaseWallet,
    braveWallet,
    ledgerWallet,
    argentWallet,
    trustWallet,
    okxWallet,
    rabbyWallet,
    safeWallet,
    zerionWallet,
    imTokenWallet,
    frameWallet,
    oneKeyWallet,
    tahoWallet,
    xdefiWallet,
} from '@rainbow-me/rainbowkit/wallets';
import { mainnet, polygon, optimism, arbitrum, base, sepolia } from 'wagmi/chains';

// Custom Anvil chain for local development
export const anvil = {
    id: 31337,
    name: 'Anvil',
    nativeCurrency: {
        decimals: 18,
        name: 'Ether',
        symbol: 'ETH',
    },
    rpcUrls: {
        default: {
            http: ['http://127.0.0.1:8545'],
        },
    },
    blockExplorers: {
        default: { name: 'Local', url: 'http://localhost:8545' },
    },
} as const;

// Custom chains with specific RPC URLs
const customSepolia = {
    ...sepolia,
    rpcUrls: {
        default: {
            http: [(import.meta as any).env?.VITE_ETHEREUM_SEPOLIA_RPC || sepolia.rpcUrls.default.http[0]],
        },
    },
} as const;

const customOptimismSepolia = {
    ...optimism,
    id: 11155420,
    name: 'Optimism Sepolia',
    rpcUrls: {
        default: {
            http: [(import.meta as any).env?.VITE_OPTIMISM_SEPOLIA_RPC || 'https://sepolia.optimism.io'],
        },
    },
    blockExplorers: {
        default: {
            name: 'Optimism Sepolia Explorer',
            url: 'https://sepolia-optimism.etherscan.io'
        },
    },
} as const;

const customArbitrumSepolia = {
    ...arbitrum,
    id: 421614,
    name: 'Arbitrum Sepolia',
    rpcUrls: {
        default: {
            http: [(import.meta as any).env?.VITE_ARBITRUM_SEPOLIA_RPC || 'https://sepolia-rollup.arbitrum.io/rpc'],
        },
    },
    blockExplorers: {
        default: {
            name: 'Arbitrum Sepolia Explorer',
            url: 'https://sepolia.arbiscan.io'
        },
    },
} as const;

const customBaseSepolia = {
    ...base,
    id: 84532,
    name: 'Base Sepolia',
    rpcUrls: {
        default: {
            http: [(import.meta as any).env?.VITE_BASE_SEPOLIA_RPC || 'https://sepolia.base.org'],
        },
    },
    blockExplorers: {
        default: {
            name: 'Base Sepolia Explorer',
            url: 'https://sepolia.basescan.org'
        },
    },
} as const;

const customPolygonAmoy = {
    ...polygon,
    id: 80002,
    name: 'Polygon Amoy',
    rpcUrls: {
        default: {
            http: [(import.meta as any).env?.VITE_POLYGON_AMOY_RPC || 'https://rpc-amoy.polygon.technology'],
        },
    },
    blockExplorers: {
        default: {
            name: 'Polygon Amoy Explorer',
            url: 'https://www.oklink.com/amoy'
        },
    },
} as const;

// Get WalletConnect project ID from environment or use default
const projectId = (import.meta as any).env?.VITE_WALLET_CONNECT_PROJECT_ID || '025acf6134d38681e310bb7e00022000';

export const config = getDefaultConfig({
    appName: 'Gas Optimization Hook',
    projectId,
    chains: [
        anvil, // Local development
        mainnet, // Ethereum mainnet
        customSepolia, // Ethereum Sepolia testnet
        customOptimismSepolia, // Optimism Sepolia testnet
        customArbitrumSepolia, // Arbitrum Sepolia testnet
        customBaseSepolia, // Base Sepolia testnet
        customPolygonAmoy, // Polygon Amoy testnet
    ],
    wallets: [
        {
            groupName: 'Popular',
            wallets: [
                metaMaskWallet,
                coinbaseWallet,
                walletConnectWallet,
                injectedWallet, // This will detect Uniswap Wallet and other injected wallets
                rainbowWallet,
            ],
        },
        {
            groupName: 'More Wallets',
            wallets: [
                trustWallet,
                braveWallet,
                ledgerWallet,
                argentWallet,
                okxWallet,
                rabbyWallet,
                safeWallet,
                zerionWallet,
                imTokenWallet,
                frameWallet,
                oneKeyWallet,
                tahoWallet,
                xdefiWallet,
            ],
        },
    ],
    ssr: true,
}); 