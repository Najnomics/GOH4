// Contract addresses and blockchain configuration
export const CONTRACT_ADDRESSES = {
    GAS_OPTIMIZATION_HOOK: (import.meta as any).env?.VITE_GAS_OPTIMIZATION_HOOK_ADDRESS || '',
    COST_CALCULATOR: (import.meta as any).env?.VITE_COST_CALCULATOR_ADDRESS || '',
    GAS_PRICE_ORACLE: (import.meta as any).env?.VITE_GAS_PRICE_ORACLE_ADDRESS || '',
    CROSS_CHAIN_MANAGER: (import.meta as any).env?.VITE_CROSS_CHAIN_MANAGER_ADDRESS || '',
} as const;

export const API_KEYS = {
    ETHERSCAN: (import.meta as any).env?.VITE_ETHERSCAN_API_KEY || '',
    ARBISCAN: (import.meta as any).env?.VITE_ARBISCAN_API_KEY || '',
    OPTIMISTIC_ETHERSCAN: (import.meta as any).env?.VITE_OPTIMISTIC_ETHERSCAN_API_KEY || '',
    POLYGONSCAN: (import.meta as any).env?.VITE_POLYGONSCAN_API_KEY || '',
    BASESCAN: (import.meta as any).env?.VITE_BASESCAN_API_KEY || '',
} as const;

export const RPC_URLS = {
    ETHEREUM_SEPOLIA: (import.meta as any).env?.VITE_ETHEREUM_SEPOLIA_RPC || 'https://eth-sepolia.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
    OPTIMISM_SEPOLIA: (import.meta as any).env?.VITE_OPTIMISM_SEPOLIA_RPC || 'https://opt-sepolia.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
    ARBITRUM_SEPOLIA: (import.meta as any).env?.VITE_ARBITRUM_SEPOLIA_RPC || 'https://arb-sepolia.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
    BASE_SEPOLIA: (import.meta as any).env?.VITE_BASE_SEPOLIA_RPC || 'https://base-sepolia.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
    UNICHAIN_SEPOLIA: (import.meta as any).env?.VITE_UNICHAIN_SEPOLIA_RPC || 'https://unichain-sepolia.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
    POLYGON_AMOY: (import.meta as any).env?.VITE_POLYGON_AMOY_RPC || 'https://polygon-amoy.g.alchemy.com/v2/-h2-JZZFDFZS_s_4N6hzIl8f0gUJePBt',
} as const;

// Chain configurations
export const CHAIN_CONFIGS = {
    ETHEREUM_SEPOLIA: {
        id: 11155111,
        name: 'Ethereum Sepolia',
        rpcUrl: RPC_URLS.ETHEREUM_SEPOLIA,
        blockExplorer: 'https://sepolia.etherscan.io',
        apiKey: API_KEYS.ETHERSCAN,
    },
    OPTIMISM_SEPOLIA: {
        id: 11155420,
        name: 'Optimism Sepolia',
        rpcUrl: RPC_URLS.OPTIMISM_SEPOLIA,
        blockExplorer: 'https://sepolia-optimism.etherscan.io',
        apiKey: API_KEYS.OPTIMISTIC_ETHERSCAN,
    },
    ARBITRUM_SEPOLIA: {
        id: 421614,
        name: 'Arbitrum Sepolia',
        rpcUrl: RPC_URLS.ARBITRUM_SEPOLIA,
        blockExplorer: 'https://sepolia.arbiscan.io',
        apiKey: API_KEYS.ARBISCAN,
    },
    BASE_SEPOLIA: {
        id: 84532,
        name: 'Base Sepolia',
        rpcUrl: RPC_URLS.BASE_SEPOLIA,
        blockExplorer: 'https://sepolia.basescan.org',
        apiKey: API_KEYS.BASESCAN,
    },
    POLYGON_AMOY: {
        id: 80002,
        name: 'Polygon Amoy',
        rpcUrl: RPC_URLS.POLYGON_AMOY,
        blockExplorer: 'https://www.oklink.com/amoy',
        apiKey: API_KEYS.POLYGONSCAN,
    },
} as const;

// Helper function to get contract address
export const getContractAddress = (contractName: keyof typeof CONTRACT_ADDRESSES): string => {
    const address = CONTRACT_ADDRESSES[contractName];
    if (!address) {
        console.warn(`Contract address for ${contractName} not found. Please check your environment variables.`);
    }
    return address;
};

// Helper function to get chain config
export const getChainConfig = (chainId: number) => {
    return Object.values(CHAIN_CONFIGS).find(config => config.id === chainId);
};

// Helper function to get RPC URL for a chain
export const getRpcUrl = (chainId: number): string => {
    const config = getChainConfig(chainId);
    return config?.rpcUrl || '';
};

// Helper function to get block explorer URL for a chain
export const getBlockExplorerUrl = (chainId: number): string => {
    const config = getChainConfig(chainId);
    return config?.blockExplorer || '';
}; 