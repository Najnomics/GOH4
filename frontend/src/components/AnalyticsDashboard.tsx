import { useState } from 'react';
import { motion } from 'framer-motion';
import {
    TrendingUp,
    DollarSign,
    Zap,
    BarChart3,
    ArrowUpRight,
    ArrowDownRight,
    Activity,
    Users,
    Network
} from 'lucide-react';
import clsx from 'clsx';

interface AnalyticsData {
    totalVolume: number;
    totalSwaps: number;
    totalSavings: number;
    averageGasSaved: number;
    activeUsers: number;
    supportedChains: number;
    volumeChange: number;
    swapsChange: number;
    savingsChange: number;
    usersChange: number;
}

interface ChainData {
    name: string;
    volume: number;
    swaps: number;
    savings: number;
    gasPrice: number;
    color: string;
}

const mockAnalyticsData: AnalyticsData = {
    totalVolume: 1247000,
    totalSwaps: 15600,
    totalSavings: 124700,
    averageGasSaved: 8.0,
    activeUsers: 3400,
    supportedChains: 6,
    volumeChange: 12.5,
    swapsChange: 8.3,
    savingsChange: 15.7,
    usersChange: 22.1,
};

const chainData: ChainData[] = [
    { name: 'Ethereum', volume: 450000, swaps: 5200, savings: 45000, gasPrice: 25, color: '#627EEA' },
    { name: 'Arbitrum', volume: 320000, swaps: 3800, savings: 32000, gasPrice: 0.1, color: '#28A0F0' },
    { name: 'Polygon', volume: 280000, swaps: 4200, savings: 28000, gasPrice: 0.05, color: '#8247E5' },
    { name: 'Base', volume: 120000, swaps: 1800, savings: 12000, gasPrice: 0.01, color: '#0052FF' },
    { name: 'Optimism', volume: 77000, swaps: 600, savings: 7700, gasPrice: 0.001, color: '#FF0420' },
];

export default function AnalyticsDashboard() {
    const [timeRange, setTimeRange] = useState<'24h' | '7d' | '30d' | '1y'>('7d');

    const formatNumber = (num: number) => {
        if (num >= 1000000) {
            return `$${(num / 1000000).toFixed(1)}M`;
        } else if (num >= 1000) {
            return `$${(num / 1000).toFixed(1)}K`;
        }
        return `$${num.toFixed(0)}`;
    };

    const formatPercentage = (num: number) => {
        const sign = num >= 0 ? '+' : '';
        return `${sign}${num.toFixed(1)}%`;
    };

    const metrics = [
        {
            label: 'Total Volume',
            value: formatNumber(mockAnalyticsData.totalVolume),
            change: mockAnalyticsData.volumeChange,
            icon: DollarSign,
            color: 'text-uniswap-green',
        },
        {
            label: 'Total Swaps',
            value: mockAnalyticsData.totalSwaps.toLocaleString(),
            change: mockAnalyticsData.swapsChange,
            icon: BarChart3,
            color: 'text-uniswap-blue',
        },
        {
            label: 'Total Savings',
            value: formatNumber(mockAnalyticsData.totalSavings),
            change: mockAnalyticsData.savingsChange,
            icon: Zap,
            color: 'text-uniswap-pink',
        },
        {
            label: 'Active Users',
            value: mockAnalyticsData.activeUsers.toLocaleString(),
            change: mockAnalyticsData.usersChange,
            icon: Users,
            color: 'text-uniswap-purple',
        },
    ];

    const recentTransactions = [
        { from: 'ETH', to: 'USDC', amount: '2.5 ETH', savings: '$12.45', chain: 'Arbitrum', time: '2 min ago' },
        { from: 'WETH', to: 'DAI', amount: '1.2 WETH', savings: '$8.23', chain: 'Polygon', time: '5 min ago' },
        { from: 'USDC', to: 'ETH', amount: '5000 USDC', savings: '$15.67', chain: 'Base', time: '8 min ago' },
        { from: 'DAI', to: 'WETH', amount: '3000 DAI', savings: '$9.12', chain: 'Ethereum', time: '12 min ago' },
        { from: 'ETH', to: 'USDT', amount: '0.8 ETH', savings: '$6.78', chain: 'Optimism', time: '15 min ago' },
    ];

    return (
        <div className="space-y-8">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-text-primary">Analytics</h2>
                    <p className="text-text-secondary mt-1">Track your gas optimization performance</p>
                </div>

                <div className="flex items-center space-x-2">
                    {(['24h', '7d', '30d', '1y'] as const).map((range) => (
                        <button
                            key={range}
                            onClick={() => setTimeRange(range)}
                            className={clsx(
                                "px-3 py-1 rounded-lg text-sm font-medium transition-colors",
                                timeRange === range
                                    ? "bg-uniswap-pink text-white"
                                    : "bg-background-tertiary text-text-secondary hover:text-text-primary"
                            )}
                        >
                            {range}
                        </button>
                    ))}
                </div>
            </div>

            {/* Key Metrics */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {metrics.map((metric, index) => {
                    const Icon = metric.icon;
                    return (
                        <motion.div
                            key={metric.label}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: index * 0.1 }}
                            className="bg-background-secondary rounded-2xl border border-border-primary p-6"
                        >
                            <div className="flex items-center justify-between mb-4">
                                <div className={clsx("p-2 rounded-lg", metric.color.replace('text-', 'bg-') + '/10')}>
                                    <Icon className={clsx("w-5 h-5", metric.color)} />
                                </div>
                                <div className="flex items-center space-x-1">
                                    {metric.change >= 0 ? (
                                        <ArrowUpRight className="w-4 h-4 text-uniswap-green" />
                                    ) : (
                                        <ArrowDownRight className="w-4 h-4 text-red-500" />
                                    )}
                                    <span className={clsx(
                                        "text-sm font-medium",
                                        metric.change >= 0 ? "text-uniswap-green" : "text-red-500"
                                    )}>
                                        {formatPercentage(metric.change)}
                                    </span>
                                </div>
                            </div>
                            <p className="text-2xl font-bold text-text-primary mb-1">{metric.value}</p>
                            <p className="text-sm text-text-secondary">{metric.label}</p>
                        </motion.div>
                    );
                })}
            </div>

            {/* Charts Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Chain Performance */}
                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <h3 className="text-lg font-semibold text-text-primary mb-6">Chain Performance</h3>
                    <div className="space-y-4">
                        {chainData.map((chain, index) => (
                            <motion.div
                                key={chain.name}
                                initial={{ opacity: 0, x: -20 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ delay: index * 0.1 }}
                                className="flex items-center justify-between p-4 bg-background-primary rounded-xl border border-border-primary"
                            >
                                <div className="flex items-center space-x-3">
                                    <div
                                        className="w-4 h-4 rounded-full"
                                        style={{ backgroundColor: chain.color }}
                                    />
                                    <div>
                                        <p className="font-medium text-text-primary">{chain.name}</p>
                                        <p className="text-sm text-text-secondary">{chain.gasPrice} gwei</p>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <p className="font-medium text-text-primary">{formatNumber(chain.volume)}</p>
                                    <p className="text-sm text-text-secondary">{chain.swaps} swaps</p>
                                </div>
                            </motion.div>
                        ))}
                    </div>
                </div>

                {/* Gas Savings Trend */}
                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <h3 className="text-lg font-semibold text-text-primary mb-6">Gas Savings Trend</h3>
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <span className="text-text-secondary">Average Savings</span>
                            <span className="text-2xl font-bold text-uniswap-green">${mockAnalyticsData.averageGasSaved}</span>
                        </div>
                        <div className="h-32 bg-background-primary rounded-xl border border-border-primary flex items-center justify-center">
                            <div className="text-center">
                                <Activity className="w-8 h-8 text-text-tertiary mx-auto mb-2" />
                                <p className="text-sm text-text-secondary">Chart visualization</p>
                            </div>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="text-center p-3 bg-background-primary rounded-xl">
                                <p className="text-sm text-text-secondary">Best Chain</p>
                                <p className="font-medium text-text-primary">Arbitrum</p>
                            </div>
                            <div className="text-center p-3 bg-background-primary rounded-xl">
                                <p className="text-sm text-text-secondary">Avg Savings</p>
                                <p className="font-medium text-uniswap-green">80%</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Recent Transactions */}
            <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                <h3 className="text-lg font-semibold text-text-primary mb-6">Recent Transactions</h3>
                <div className="space-y-3">
                    {recentTransactions.map((tx, index) => (
                        <motion.div
                            key={index}
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: index * 0.05 }}
                            className="flex items-center justify-between p-4 bg-background-primary rounded-xl border border-border-primary hover:border-border-secondary transition-colors"
                        >
                            <div className="flex items-center space-x-3">
                                <div className="w-10 h-10 bg-gradient-to-br from-uniswap-pink to-uniswap-purple rounded-full flex items-center justify-center">
                                    <span className="text-white font-bold text-sm">G</span>
                                </div>
                                <div>
                                    <p className="font-medium text-text-primary">{tx.from} → {tx.to}</p>
                                    <p className="text-sm text-text-secondary">{tx.amount} • {tx.chain}</p>
                                </div>
                            </div>
                            <div className="text-right">
                                <p className="font-medium text-uniswap-green">{tx.savings}</p>
                                <p className="text-sm text-text-tertiary">{tx.time}</p>
                            </div>
                        </motion.div>
                    ))}
                </div>
            </div>

            {/* Insights */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <div className="flex items-center space-x-3 mb-4">
                        <div className="p-2 bg-uniswap-green/10 rounded-lg">
                            <TrendingUp className="w-5 h-5 text-uniswap-green" />
                        </div>
                        <h4 className="font-semibold text-text-primary">Performance</h4>
                    </div>
                    <p className="text-sm text-text-secondary mb-3">
                        Your gas optimization is performing 15% better than average users.
                    </p>
                    <div className="flex items-center space-x-2">
                        <div className="flex-1 bg-background-primary rounded-full h-2">
                            <div className="bg-uniswap-green h-2 rounded-full" style={{ width: '75%' }} />
                        </div>
                        <span className="text-sm font-medium text-uniswap-green">75%</span>
                    </div>
                </div>

                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <div className="flex items-center space-x-3 mb-4">
                        <div className="p-2 bg-uniswap-blue/10 rounded-lg">
                            <Network className="w-5 h-5 text-uniswap-blue" />
                        </div>
                        <h4 className="font-semibold text-text-primary">Network Usage</h4>
                    </div>
                    <p className="text-sm text-text-secondary mb-3">
                        You've used {mockAnalyticsData.supportedChains} different networks this month.
                    </p>
                    <div className="flex flex-wrap gap-2">
                        {chainData.slice(0, 3).map((chain) => (
                            <span
                                key={chain.name}
                                className="px-2 py-1 bg-background-primary rounded-lg text-xs text-text-secondary"
                            >
                                {chain.name}
                            </span>
                        ))}
                    </div>
                </div>

                <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                    <div className="flex items-center space-x-3 mb-4">
                        <div className="p-2 bg-uniswap-pink/10 rounded-lg">
                            <Zap className="w-5 h-5 text-uniswap-pink" />
                        </div>
                        <h4 className="font-semibold text-text-primary">Savings Goal</h4>
                    </div>
                    <p className="text-sm text-text-secondary mb-3">
                        You're on track to save ${formatNumber(mockAnalyticsData.totalSavings * 1.2)} this month.
                    </p>
                    <div className="flex items-center space-x-2">
                        <div className="flex-1 bg-background-primary rounded-full h-2">
                            <div className="bg-uniswap-pink h-2 rounded-full" style={{ width: '60%' }} />
                        </div>
                        <span className="text-sm font-medium text-uniswap-pink">60%</span>
                    </div>
                </div>
            </div>
        </div>
    );
} 