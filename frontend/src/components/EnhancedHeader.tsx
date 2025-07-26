import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    BarChart3,
    Settings,
    Menu,
    X,
    Bell,
    ChevronDown,
    ExternalLink,
    HelpCircle,
    MessageCircle,
    Zap,
    TrendingUp
} from 'lucide-react';
import { ConnectWallet } from './ConnectWallet';

interface EnhancedHeaderProps {
    activeTab: 'swap' | 'optimize' | 'analytics';
    onTabChange: (tab: 'swap' | 'optimize' | 'analytics') => void;
}

export default function EnhancedHeader({ activeTab, onTabChange }: EnhancedHeaderProps) {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [showNotifications, setShowNotifications] = useState(false);
    const [showHelp, setShowHelp] = useState(false);

    const navigationItems = [
        { id: 'swap', label: 'Swap', icon: Zap },
        { id: 'optimize', label: 'Gas Optimization', icon: TrendingUp },
        { id: 'analytics', label: 'Analytics', icon: BarChart3 },
    ] as const;

    const notifications = [
        {
            id: 1,
            title: 'Gas prices are low on Arbitrum',
            message: 'Save up to 80% on gas fees by switching to Arbitrum',
            time: '2 min ago',
            type: 'info'
        },
        {
            id: 2,
            title: 'Swap completed successfully',
            message: 'Your ETH → USDC swap saved $15.30 in gas fees',
            time: '1 hour ago',
            type: 'success'
        },
        {
            id: 3,
            title: 'New chain supported',
            message: 'Base network is now available for swaps',
            time: '2 hours ago',
            type: 'update'
        }
    ];

    const helpItems = [
        { label: 'Documentation', href: '#', icon: ExternalLink },
        { label: 'Discord Community', href: '#', icon: MessageCircle },
        { label: 'Support', href: '#', icon: HelpCircle },
    ];

    return (
        <header className="border-b border-border-primary bg-background-secondary/50 backdrop-blur-sm sticky top-0 z-40">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">
                    {/* Logo */}
                    <div className="flex items-center space-x-3">
                        <div className="w-8 h-8 bg-gradient-to-br from-uniswap-pink to-uniswap-purple rounded-lg flex items-center justify-center">
                            <span className="text-white font-bold text-sm">G</span>
                        </div>
                        <span className="text-xl font-bold text-text-primary">GasOpt</span>
                    </div>

                    {/* Desktop Navigation */}
                    <nav className="hidden md:flex items-center space-x-1">
                        {navigationItems.map((item) => {
                            const Icon = item.icon;
                            return (
                                <button
                                    key={item.id}
                                    onClick={() => onTabChange(item.id)}
                                    className={`flex items-center space-x-2 px-4 py-2 rounded-xl font-medium transition-all duration-200 ${activeTab === item.id
                                            ? 'bg-uniswap-pink text-white shadow-lg shadow-uniswap-pink/25'
                                            : 'text-text-secondary hover:text-text-primary hover:bg-background-tertiary'
                                        }`}
                                >
                                    <Icon className="w-4 h-4" />
                                    <span>{item.label}</span>
                                </button>
                            );
                        })}
                    </nav>

                    {/* Right side */}
                    <div className="flex items-center space-x-2">
                        {/* Notifications */}
                        <div className="relative">
                            <button
                                onClick={() => setShowNotifications(!showNotifications)}
                                className="p-2 hover:bg-background-tertiary rounded-xl transition-colors relative"
                            >
                                <Bell className="w-5 h-5 text-text-secondary" />
                                <div className="absolute -top-1 -right-1 w-3 h-3 bg-uniswap-pink rounded-full" />
                            </button>

                            <AnimatePresence>
                                {showNotifications && (
                                    <motion.div
                                        initial={{ opacity: 0, y: 10, scale: 0.95 }}
                                        animate={{ opacity: 1, y: 0, scale: 1 }}
                                        exit={{ opacity: 0, y: 10, scale: 0.95 }}
                                        className="absolute right-0 top-12 w-80 bg-background-secondary border border-border-primary rounded-2xl shadow-xl p-4 space-y-3"
                                    >
                                        <div className="flex items-center justify-between">
                                            <h3 className="font-semibold text-text-primary">Notifications</h3>
                                            <button className="text-sm text-uniswap-pink hover:text-uniswap-pink/80">
                                                Mark all read
                                            </button>
                                        </div>

                                        <div className="space-y-2 max-h-64 overflow-y-auto">
                                            {notifications.map((notification) => (
                                                <div
                                                    key={notification.id}
                                                    className="p-3 bg-background-primary rounded-xl border border-border-primary hover:border-border-secondary transition-colors cursor-pointer"
                                                >
                                                    <div className="flex items-start justify-between">
                                                        <div className="flex-1">
                                                            <p className="font-medium text-text-primary text-sm">
                                                                {notification.title}
                                                            </p>
                                                            <p className="text-text-secondary text-xs mt-1">
                                                                {notification.message}
                                                            </p>
                                                        </div>
                                                        <span className="text-text-tertiary text-xs">
                                                            {notification.time}
                                                        </span>
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>

                        {/* Help Menu */}
                        <div className="relative">
                            <button
                                onClick={() => setShowHelp(!showHelp)}
                                className="p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                            >
                                <HelpCircle className="w-5 h-5 text-text-secondary" />
                            </button>

                            <AnimatePresence>
                                {showHelp && (
                                    <motion.div
                                        initial={{ opacity: 0, y: 10, scale: 0.95 }}
                                        animate={{ opacity: 1, y: 0, scale: 1 }}
                                        exit={{ opacity: 0, y: 10, scale: 0.95 }}
                                        className="absolute right-0 top-12 w-48 bg-background-secondary border border-border-primary rounded-2xl shadow-xl p-2"
                                    >
                                        {helpItems.map((item) => {
                                            const Icon = item.icon;
                                            return (
                                                <a
                                                    key={item.label}
                                                    href={item.href}
                                                    className="flex items-center space-x-3 px-3 py-2 rounded-xl text-text-secondary hover:text-text-primary hover:bg-background-tertiary transition-colors"
                                                >
                                                    <Icon className="w-4 h-4" />
                                                    <span className="text-sm">{item.label}</span>
                                                </a>
                                            );
                                        })}
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>

                        {/* Settings */}
                        <button className="p-2 hover:bg-background-tertiary rounded-xl transition-colors">
                            <Settings className="w-5 h-5 text-text-secondary" />
                        </button>

                        {/* Connect Wallet */}
                        <ConnectWallet />

                        {/* Mobile menu button */}
                        <button
                            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                            className="md:hidden p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                        >
                            {isMobileMenuOpen ? (
                                <X className="w-5 h-5 text-text-secondary" />
                            ) : (
                                <Menu className="w-5 h-5 text-text-secondary" />
                            )}
                        </button>
                    </div>
                </div>

                {/* Mobile Navigation */}
                <AnimatePresence>
                    {isMobileMenuOpen && (
                        <motion.div
                            initial={{ opacity: 0, height: 0 }}
                            animate={{ opacity: 1, height: 'auto' }}
                            exit={{ opacity: 0, height: 0 }}
                            className="md:hidden border-t border-border-primary bg-background-secondary"
                        >
                            <div className="px-4 py-4 space-y-2">
                                {navigationItems.map((item) => {
                                    const Icon = item.icon;
                                    return (
                                        <button
                                            key={item.id}
                                            onClick={() => {
                                                onTabChange(item.id);
                                                setIsMobileMenuOpen(false);
                                            }}
                                            className={`w-full flex items-center space-x-3 px-4 py-3 rounded-xl font-medium transition-colors ${activeTab === item.id
                                                    ? 'bg-uniswap-pink text-white'
                                                    : 'text-text-secondary hover:text-text-primary hover:bg-background-tertiary'
                                                }`}
                                        >
                                            <Icon className="w-4 h-4" />
                                            <span>{item.label}</span>
                                        </button>
                                    );
                                })}
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>
        </header>
    );
} 