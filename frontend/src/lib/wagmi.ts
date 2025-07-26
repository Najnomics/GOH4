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

// Get WalletConnect project ID from environment or use default
const projectId = (import.meta as any).env?.VITE_WALLET_CONNECT_PROJECT_ID || '025acf6134d38681e310bb7e00022000';

export const config = getDefaultConfig({
    appName: 'Gas Optimization Hook',
    projectId,
    chains: [anvil, mainnet, sepolia, polygon, optimism, arbitrum, base],
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