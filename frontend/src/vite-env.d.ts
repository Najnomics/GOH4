/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_WALLET_CONNECT_PROJECT_ID: string
    readonly VITE_ETHEREUM_SEPOLIA_RPC: string
    readonly VITE_OPTIMISM_SEPOLIA_RPC: string
    readonly VITE_ARBITRUM_SEPOLIA_RPC: string
    readonly VITE_BASE_SEPOLIA_RPC: string
    readonly VITE_UNICHAIN_SEPOLIA_RPC: string
    readonly VITE_POLYGON_AMOY_RPC: string
    readonly VITE_ETHERSCAN_API_KEY: string
    readonly VITE_ARBISCAN_API_KEY: string
    readonly VITE_OPTIMISTIC_ETHERSCAN_API_KEY: string
    readonly VITE_POLYGONSCAN_API_KEY: string
    readonly VITE_BASESCAN_API_KEY: string
    readonly VITE_GAS_OPTIMIZATION_HOOK_ADDRESS: string
    readonly VITE_COST_CALCULATOR_ADDRESS: string
    readonly VITE_GAS_PRICE_ORACLE_ADDRESS: string
    readonly VITE_CROSS_CHAIN_MANAGER_ADDRESS: string
}

interface ImportMeta {
    readonly env: ImportMetaEnv
} 