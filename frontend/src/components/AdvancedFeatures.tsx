import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
    Settings, 
    Zap, 
    TrendingUp, 
    Shield, 
    Clock, 
    DollarSign,
    ChevronDown,
    ChevronUp,
    Info,
    AlertTriangle
} from 'lucide-react';
import clsx from 'clsx';

interface AdvancedSettings {
    slippageTolerance: number;
    deadline: number;
    gasOptimization: boolean;
    routeOptimization: boolean;
    MEVProtection: boolean;
    limitOrder: boolean;
    limitPrice: string;
    limitExpiry: number;
}

export default function AdvancedFeatures() {
    const [isExpanded, setIsExpanded] = useState(false);
    const [settings, setSettings] = useState<AdvancedSettings>({
        slippageTolerance: 0.5,
        deadline: 20,
        gasOptimization: true,
        routeOptimization: true,
        MEVProtection: true,
        limitOrder: false,
        limitPrice: '',
        limitExpiry: 24,
    });

    const features = [
        {
            title: 'MEV Protection',
            description: 'Protect your transactions from front-running and sandwich attacks',
            icon: Shield,
            enabled: settings.MEVProtection,
            onToggle: () => setSettings(prev => ({ ...prev, MEVProtection: !prev.MEVProtection })),
            color: 'text-blue-500',
            bgColor: 'bg-blue-500/10'
        },
        {
            title: 'Route Optimization',
            description: 'Find the most efficient path across multiple DEXs and chains',
            icon: TrendingUp,
            enabled: settings.routeOptimization,
            onToggle: () => setSettings(prev => ({ ...prev, routeOptimization: !prev.routeOptimization })),
            color: 'text-green-500',
            bgColor: 'bg-green-500/10'
        },
        {
            title: 'Gas Optimization',
            description: 'Automatically route to the cheapest chain for gas savings',
            icon: Zap,
            enabled: settings.gasOptimization,
            onToggle: () => setSettings(prev => ({ ...prev, gasOptimization: !prev.gasOptimization })),
            color: 'text-yellow-500',
            bgColor: 'bg-yellow-500/10'
        },
        {
            title: 'Limit Orders',
            description: 'Set price targets and execute trades automatically',
            icon: Clock,
            enabled: settings.limitOrder,
            onToggle: () => setSettings(prev => ({ ...prev, limitOrder: !prev.limitOrder })),
            color: 'text-purple-500',
            bgColor: 'bg-purple-500/10'
        }
    ];

    return (
        <div className="bg-background-secondary rounded-2xl border border-border-primary p-6">
            <div className="flex items-center justify-between mb-6">
                <div className="flex items-center space-x-3">
                    <div className="p-2 bg-uniswap-pink/10 rounded-lg">
                        <Settings className="w-5 h-5 text-uniswap-pink" />
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-text-primary">Advanced Features</h3>
                        <p className="text-sm text-text-secondary">Customize your trading experience</p>
                    </div>
                </div>
                <button
                    onClick={() => setIsExpanded(!isExpanded)}
                    className="p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                >
                    {isExpanded ? (
                        <ChevronUp className="w-5 h-5 text-text-secondary" />
                    ) : (
                        <ChevronDown className="w-5 h-5 text-text-secondary" />
                    )}
                </button>
            </div>

            <AnimatePresence>
                {isExpanded && (
                    <motion.div
                        initial={{ opacity: 0, height: 0 }}
                        animate={{ opacity: 1, height: 'auto' }}
                        exit={{ opacity: 0, height: 0 }}
                        className="space-y-6"
                    >
                        {/* Basic Settings */}
                        <div className="space-y-4">
                            <h4 className="font-medium text-text-primary">Transaction Settings</h4>
                            
                            {/* Slippage Tolerance */}
                            <div className="space-y-2">
                                <div className="flex items-center justify-between">
                                    <label className="text-sm font-medium text-text-secondary">Slippage Tolerance</label>
                                    <span className="text-sm text-text-primary">{settings.slippageTolerance}%</span>
                                </div>
                                <div className="flex space-x-2">
                                    {[0.1, 0.5, 1.0, 2.0].map((value) => (
                                        <button
                                            key={value}
                                            onClick={() => setSettings(prev => ({ ...prev, slippageTolerance: value }))}
                                            className={clsx(
                                                "px-3 py-1 rounded-lg text-sm font-medium transition-colors",
                                                settings.slippageTolerance === value
                                                    ? "bg-uniswap-pink text-white"
                                                    : "bg-background-tertiary text-text-secondary hover:text-text-primary"
                                            )}
                                        >
                                            {value}%
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Transaction Deadline */}
                            <div className="space-y-2">
                                <div className="flex items-center justify-between">
                                    <label className="text-sm font-medium text-text-secondary">Transaction Deadline</label>
                                    <span className="text-sm text-text-primary">{settings.deadline} minutes</span>
                                </div>
                                <input
                                    type="range"
                                    min="1"
                                    max="60"
                                    value={settings.deadline}
                                    onChange={(e) => setSettings(prev => ({ ...prev, deadline: parseInt(e.target.value) }))}
                                    className="w-full h-2 bg-background-tertiary rounded-lg appearance-none cursor-pointer slider"
                                />
                            </div>
                        </div>

                        {/* Advanced Features */}
                        <div className="space-y-4">
                            <h4 className="font-medium text-text-primary">Advanced Features</h4>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {features.map((feature) => {
                                    const Icon = feature.icon;
                                    return (
                                        <div
                                            key={feature.title}
                                            className={clsx(
                                                "p-4 rounded-xl border transition-all duration-200 cursor-pointer",
                                                feature.enabled
                                                    ? "border-uniswap-pink/30 bg-uniswap-pink/5"
                                                    : "border-border-primary bg-background-primary hover:border-border-secondary"
                                            )}
                                            onClick={feature.onToggle}
                                        >
                                            <div className="flex items-start justify-between mb-3">
                                                <div className={clsx("p-2 rounded-lg", feature.bgColor)}>
                                                    <Icon className={clsx("w-4 h-4", feature.color)} />
                                                </div>
                                                <div className={clsx(
                                                    "w-6 h-4 rounded-full transition-colors",
                                                    feature.enabled ? "bg-uniswap-pink" : "bg-background-tertiary"
                                                )}>
                                                    <div className={clsx(
                                                        "w-3 h-3 rounded-full bg-white transition-transform",
                                                        feature.enabled ? "translate-x-2" : "translate-x-0"
                                                    )} />
                                                </div>
                                            </div>
                                            <h5 className="font-medium text-text-primary mb-1">{feature.title}</h5>
                                            <p className="text-sm text-text-secondary">{feature.description}</p>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>

                        {/* Limit Order Settings */}
                        <AnimatePresence>
                            {settings.limitOrder && (
                                <motion.div
                                    initial={{ opacity: 0, height: 0 }}
                                    animate={{ opacity: 1, height: 'auto' }}
                                    exit={{ opacity: 0, height: 0 }}
                                    className="space-y-4 p-4 bg-background-primary rounded-xl border border-border-primary"
                                >
                                    <h4 className="font-medium text-text-primary">Limit Order Settings</h4>
                                    
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                        <div className="space-y-2">
                                            <label className="text-sm font-medium text-text-secondary">Limit Price</label>
                                            <input
                                                type="number"
                                                placeholder="0.0"
                                                value={settings.limitPrice}
                                                onChange={(e) => setSettings(prev => ({ ...prev, limitPrice: e.target.value }))}
                                                className="w-full px-3 py-2 bg-background-tertiary border border-border-primary rounded-lg text-text-primary focus:outline-none focus:border-uniswap-pink"
                                            />
                                        </div>
                                        
                                        <div className="space-y-2">
                                            <label className="text-sm font-medium text-text-secondary">Expiry (hours)</label>
                                            <select
                                                value={settings.limitExpiry}
                                                onChange={(e) => setSettings(prev => ({ ...prev, limitExpiry: parseInt(e.target.value) }))}
                                                className="w-full px-3 py-2 bg-background-tertiary border border-border-primary rounded-lg text-text-primary focus:outline-none focus:border-uniswap-pink"
                                            >
                                                <option value={1}>1 hour</option>
                                                <option value={6}>6 hours</option>
                                                <option value={12}>12 hours</option>
                                                <option value={24}>24 hours</option>
                                                <option value={48}>48 hours</option>
                                            </select>
                                        </div>
                                    </div>
                                </motion.div>
                            )}
                        </AnimatePresence>

                        {/* Risk Warning */}
                        <div className="flex items-start space-x-3 p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-xl">
                            <AlertTriangle className="w-5 h-5 text-yellow-500 mt-0.5" />
                            <div>
                                <p className="text-sm font-medium text-yellow-500 mb-1">Risk Warning</p>
                                <p className="text-sm text-text-secondary">
                                    Advanced features may involve additional risks. Ensure you understand the implications before enabling.
                                </p>
                            </div>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Quick Stats */}
            <div className="mt-6 pt-6 border-t border-border-primary">
                <div className="grid grid-cols-2 gap-4">
                    <div className="text-center">
                        <p className="text-sm text-text-secondary">Avg Gas Saved</p>
                        <p className="text-lg font-bold text-uniswap-green">80%</p>
                    </div>
                    <div className="text-center">
                        <p className="text-sm text-text-secondary">Success Rate</p>
                        <p className="text-lg font-bold text-uniswap-blue">99.8%</p>
                    </div>
                </div>
            </div>
        </div>
    );
} 