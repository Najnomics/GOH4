import { useState } from 'react'
import { motion } from 'framer-motion'
import EnhancedHeader from './components/EnhancedHeader'
import EnhancedSwapInterface from './components/EnhancedSwapInterface'
import GasOptimizationPanel from './components/GasOptimizationPanel'
import AnalyticsDashboard from './components/AnalyticsDashboard'
import AdvancedFeatures from './components/AdvancedFeatures'
import EnhancedFooter from './components/EnhancedFooter'

function App() {
    const [activeTab, setActiveTab] = useState<'swap' | 'optimize' | 'analytics'>('swap')

    return (
        <div className="min-h-screen bg-background-primary">
            {/* Enhanced Header */}
            <EnhancedHeader activeTab={activeTab} onTabChange={setActiveTab} />

            {/* Main Content */}
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                <motion.div
                    key={activeTab}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: 20 }}
                    transition={{ duration: 0.3 }}
                >
                    {activeTab === 'swap' && (
                        <div className="space-y-8">
                            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                                {/* Left Column - Enhanced Swap Interface */}
                                <div className="lg:col-span-2">
                                    <EnhancedSwapInterface />
                                </div>

                                {/* Right Column - Gas Optimization Panel */}
                                <div className="lg:col-span-1">
                                    <div className="sticky top-8 space-y-6">
                                        <GasOptimizationPanel />
                                        <AdvancedFeatures />
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {activeTab === 'optimize' && (
                        <div className="space-y-8">
                            {/* Gas Optimization Dashboard */}
                            <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                                <h3 className="text-lg font-semibold text-text-primary mb-4">Gas Optimization Dashboard</h3>
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                                    <div className="p-4 bg-background-tertiary rounded-xl">
                                        <p className="text-sm text-text-secondary">Total Savings</p>
                                        <p className="text-2xl font-bold text-uniswap-green">$1,247</p>
                                    </div>
                                    <div className="p-4 bg-background-tertiary rounded-xl">
                                        <p className="text-sm text-text-secondary">Swaps Optimized</p>
                                        <p className="text-2xl font-bold text-text-primary">156</p>
                                    </div>
                                    <div className="p-4 bg-background-tertiary rounded-xl">
                                        <p className="text-sm text-text-secondary">Avg Savings</p>
                                        <p className="text-2xl font-bold text-uniswap-green">$8.0</p>
                                    </div>
                                    <div className="p-4 bg-background-tertiary rounded-xl">
                                        <p className="text-sm text-text-secondary">Time Saved</p>
                                        <p className="text-2xl font-bold text-uniswap-blue">2.3h</p>
                                    </div>
                                </div>
                            </div>

                            {/* Recent Optimizations */}
                            <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
                                <h3 className="text-lg font-semibold text-text-primary mb-4">Recent Optimizations</h3>
                                <div className="space-y-3">
                                    {[
                                        { from: 'ETH', to: 'USDC', savings: '$12.45', chain: 'Arbitrum' },
                                        { from: 'WETH', to: 'DAI', savings: '$8.23', chain: 'Polygon' },
                                        { from: 'USDC', to: 'ETH', savings: '$15.67', chain: 'Base' },
                                    ].map((tx, index) => (
                                        <div key={index} className="flex items-center justify-between p-3 bg-background-tertiary rounded-xl">
                                            <div className="flex items-center space-x-3">
                                                <div className="w-8 h-8 bg-gradient-to-br from-uniswap-pink to-uniswap-purple rounded-full" />
                                                <div>
                                                    <p className="font-medium text-text-primary">{tx.from} → {tx.to}</p>
                                                    <p className="text-sm text-text-tertiary">via {tx.chain}</p>
                                                </div>
                                            </div>
                                            <div className="text-right">
                                                <p className="font-medium text-uniswap-green">{tx.savings}</p>
                                                <p className="text-sm text-text-tertiary">saved</p>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    )}

                    {activeTab === 'analytics' && (
                        <AnalyticsDashboard />
                    )}
                </motion.div>
            </main>

            {/* Enhanced Footer */}
            <EnhancedFooter />
        </div>
    )
}

export default App 