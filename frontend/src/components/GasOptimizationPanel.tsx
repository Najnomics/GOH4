import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Zap, TrendingDown, Clock, Network, Shield, Info, ArrowRight } from 'lucide-react';
import clsx from 'clsx';

interface ChainData {
    id: number;
    name: string;
    shortName: string;
    gasPrice: number; // in gwei
    gasCostUSD: number;
    avgBlockTime: number;
    tvl: string;
    status: 'optimal' | 'moderate' | 'expensive';
    isRecommended: boolean;
}

interface GasOptimizationData {
    currentChain: ChainData;
    recommendedChain: ChainData;
    gasSavings: number;
    timeSavings: number;
    crossChainFee: number;
    totalSavings: number;
}

const CHAINS: ChainData[] = [
    {
        id: 1,
        name: 'Ethereum Mainnet',
        shortName: 'ETH',
        gasPrice: 45.2,
        gasCostUSD: 52.30,
        avgBlockTime: 12,
        tvl: '$28.4B',
        status: 'expensive',
        isRecommended: false
    },
    {
        id: 42161,
        name: 'Arbitrum One',
        shortName: 'ARB',
        gasPrice: 0.8,
        gasCostUSD: 2.15,
        avgBlockTime: 0.25,
        tvl: '$2.8B',
        status: 'optimal',
        isRecommended: true
    },
    {
        id: 137,
        name: 'Polygon PoS',
        shortName: 'MATIC',
        gasPrice: 35.0,
        gasCostUSD: 0.89,
        avgBlockTime: 2,
        tvl: '$1.2B',
        status: 'optimal',
        isRecommended: false
    },
    {
        id: 10,
        name: 'Optimism',
        shortName: 'OP',
        gasPrice: 0.5,
        gasCostUSD: 1.23,
        avgBlockTime: 2,
        tvl: '$1.8B',
        status: 'optimal',
        isRecommended: false
    },
    {
        id: 8453,
        name: 'Base',
        shortName: 'BASE',
        gasPrice: 0.3,
        gasCostUSD: 0.95,
        avgBlockTime: 2,
        tvl: '$2.1B',
        status: 'optimal',
        isRecommended: false
    },
];

export default function GasOptimizationPanel() {
    const [optimizationData, setOptimizationData] = useState<GasOptimizationData | null>(null);
    const [isExpanded, setIsExpanded] = useState(false);

    useEffect(() => {
        // Mock data - replace with actual gas optimization logic
        const currentChain = CHAINS[0]; // Ethereum
        const recommendedChain = CHAINS[1]; // Arbitrum

        setOptimizationData({
            currentChain,
            recommendedChain,
            gasSavings: 95.9, // 95.9% savings
            timeSavings: 98, // 98% faster
            crossChainFee: 5.50, // $5.50 bridge fee
            totalSavings: 44.25, // $44.25 total savings
        });
    }, []);

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'optimal': return 'text-uniswap-green';
            case 'moderate': return 'text-uniswap-yellow';
            case 'expensive': return 'text-uniswap-pink';
            default: return 'text-text-secondary';
        }
    };

    const getStatusBg = (status: string) => {
        switch (status) {
            case 'optimal': return 'bg-uniswap-green/10';
            case 'moderate': return 'bg-uniswap-yellow/10';
            case 'expensive': return 'bg-uniswap-pink/10';
            default: return 'bg-background-tertiary';
        }
    };

    if (!optimizationData) {
        return (
            <div className="w-full max-w-md mx-auto">
                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <div className="animate-pulse space-y-4">
                        <div className="h-4 bg-background-tertiary rounded w-3/4"></div>
                        <div className="h-8 bg-background-tertiary rounded"></div>
                        <div className="h-4 bg-background-tertiary rounded w-1/2"></div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="w-full max-w-md mx-auto">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-background-secondary rounded-2xl border border-border-primary overflow-hidden"
            >
                {/* Header */}
                <div className="p-6 border-b border-border-primary">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                            <Zap className="w-5 h-5 text-uniswap-yellow" />
                            <h3 className="text-lg font-semibold text-text-primary">Gas Optimization</h3>
                        </div>
                        <button
                            onClick={() => setIsExpanded(!isExpanded)}
                            className="p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                        >
                            <Info className="w-4 h-4 text-text-secondary" />
                        </button>
                    </div>

                    {/* Savings Summary */}
                    <div className="mt-4 p-4 bg-background-tertiary rounded-xl">
                        <div className="flex items-center justify-between">
                            <div>
                                <p className="text-sm text-text-secondary">Total Savings</p>
                                <p className="text-2xl font-bold text-uniswap-green">${optimizationData.totalSavings}</p>
                            </div>
                            <div className="text-right">
                                <p className="text-sm text-text-secondary">Gas Savings</p>
                                <p className="text-lg font-semibold text-uniswap-green">{optimizationData.gasSavings}%</p>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Current vs Recommended */}
                <div className="p-6 space-y-4">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                            <div className="w-8 h-8 bg-gradient-to-br from-red-500 to-pink-500 rounded-full" />
                            <div>
                                <p className="font-medium text-text-primary">{optimizationData.currentChain.name}</p>
                                <p className="text-sm text-text-tertiary">Current</p>
                            </div>
                        </div>
                        <div className="text-right">
                            <p className="font-medium text-text-primary">${optimizationData.currentChain.gasCostUSD}</p>
                            <p className="text-sm text-text-tertiary">{optimizationData.currentChain.gasPrice} gwei</p>
                        </div>
                    </div>

                    <div className="flex justify-center">
                        <ArrowRight className="w-5 h-5 text-text-tertiary" />
                    </div>

                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                            <div className="w-8 h-8 bg-gradient-to-br from-green-500 to-emerald-500 rounded-full" />
                            <div>
                                <p className="font-medium text-text-primary">{optimizationData.recommendedChain.name}</p>
                                <p className="text-sm text-uniswap-green">Recommended</p>
                            </div>
                        </div>
                        <div className="text-right">
                            <p className="font-medium text-text-primary">${optimizationData.recommendedChain.gasCostUSD}</p>
                            <p className="text-sm text-text-tertiary">{optimizationData.recommendedChain.gasPrice} gwei</p>
                        </div>
                    </div>
                </div>

                {/* Expanded Details */}
                <AnimatePresence>
                    {isExpanded && (
                        <motion.div
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: 'auto', opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            className="border-t border-border-primary"
                        >
                            <div className="p-6 space-y-4">
                                {/* Cross-chain Fee */}
                                <div className="flex items-center justify-between p-3 bg-background-tertiary rounded-xl">
                                    <div className="flex items-center space-x-2">
                                        <Network className="w-4 h-4 text-text-secondary" />
                                        <span className="text-sm text-text-secondary">Bridge Fee</span>
                                    </div>
                                    <span className="text-sm font-medium text-text-primary">${optimizationData.crossChainFee}</span>
                                </div>

                                {/* Time Savings */}
                                <div className="flex items-center justify-between p-3 bg-background-tertiary rounded-xl">
                                    <div className="flex items-center space-x-2">
                                        <Clock className="w-4 h-4 text-text-secondary" />
                                        <span className="text-sm text-text-secondary">Time Savings</span>
                                    </div>
                                    <span className="text-sm font-medium text-uniswap-green">{optimizationData.timeSavings}% faster</span>
                                </div>

                                {/* All Chains Comparison */}
                                <div className="space-y-2">
                                    <h4 className="text-sm font-medium text-text-secondary">All Chains</h4>
                                    {CHAINS.map((chain) => (
                                        <div
                                            key={chain.id}
                                            className={clsx(
                                                "flex items-center justify-between p-3 rounded-xl transition-colors",
                                                chain.isRecommended
                                                    ? "bg-uniswap-green/10 border border-uniswap-green/20"
                                                    : "bg-background-tertiary"
                                            )}
                                        >
                                            <div className="flex items-center space-x-3">
                                                <div className={clsx(
                                                    "w-6 h-6 rounded-full",
                                                    chain.isRecommended
                                                        ? "bg-gradient-to-br from-green-500 to-emerald-500"
                                                        : "bg-gradient-to-br from-gray-500 to-gray-600"
                                                )} />
                                                <div>
                                                    <p className="text-sm font-medium text-text-primary">{chain.shortName}</p>
                                                    <p className="text-xs text-text-tertiary">{chain.name}</p>
                                                </div>
                                            </div>
                                            <div className="text-right">
                                                <p className="text-sm font-medium text-text-primary">${chain.gasCostUSD}</p>
                                                <div className="flex items-center space-x-1">
                                                    <span className={clsx("text-xs", getStatusColor(chain.status))}>
                                                        {chain.status}
                                                    </span>
                                                    {chain.isRecommended && (
                                                        <Shield className="w-3 h-3 text-uniswap-green" />
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </motion.div>
        </div>
    );
} 