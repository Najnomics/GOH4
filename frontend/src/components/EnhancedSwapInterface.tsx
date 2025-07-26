import { useState, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowUpDown, Settings, AlertTriangle, CheckCircle, Zap, Info, ChevronDown, X, Search } from 'lucide-react';
import { useAccount, useBalance } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import clsx from 'clsx';

interface Token {
    symbol: string;
    name: string;
    address: string;
    decimals: number;
    logoURI?: string;
    chainId: number;
}

interface SwapState {
    inputToken: Token | null;
    outputToken: Token | null;
    inputAmount: string;
    outputAmount: string;
    slippageTolerance: number;
    deadline: number;
    gasOptimization: boolean;
    routeOptimization: boolean;
}

const SUPPORTED_TOKENS: Token[] = [
    {
        symbol: 'ETH',
        name: 'Ethereum',
        address: '0x0000000000000000000000000000000000000000',
        decimals: 18,
        logoURI: 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
        chainId: 1
    },
    {
        symbol: 'USDC',
        name: 'USD Coin',
        address: '0xA0b86a33E6441b8c4C8C8C8C8C8C8C8C8C8C8C',
        decimals: 6,
        logoURI: 'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
        chainId: 1
    },
    {
        symbol: 'WETH',
        name: 'Wrapped Ether',
        address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
        decimals: 18,
        logoURI: 'https://assets.coingecko.com/coins/images/2518/small/weth.png',
        chainId: 1
    },
    {
        symbol: 'DAI',
        name: 'Dai Stablecoin',
        address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
        decimals: 18,
        logoURI: 'https://assets.coingecko.com/coins/images/9956/small/4943.png',
        chainId: 1
    },
    {
        symbol: 'USDT',
        name: 'Tether USD',
        address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        decimals: 6,
        logoURI: 'https://assets.coingecko.com/coins/images/325/small/Tether.png',
        chainId: 1
    },
];

interface TokenSelectorProps {
    isOpen: boolean;
    onClose: () => void;
    onSelect: (token: Token) => void;
    selectedToken?: Token | null;
}

function TokenSelector({ isOpen, onClose, onSelect, selectedToken }: TokenSelectorProps) {
    const [searchQuery, setSearchQuery] = useState('');

    const filteredTokens = useMemo(() => {
        return SUPPORTED_TOKENS.filter(token =>
            token.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
            token.name.toLowerCase().includes(searchQuery.toLowerCase())
        );
    }, [searchQuery]);

    return (
        <AnimatePresence>
            {isOpen && (
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
                    onClick={onClose}
                >
                    <motion.div
                        initial={{ scale: 0.95, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        exit={{ scale: 0.95, opacity: 0 }}
                        className="bg-background-secondary rounded-2xl border border-border-primary p-6 w-full max-w-md mx-4"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-semibold text-text-primary">Select Token</h3>
                            <button
                                onClick={onClose}
                                className="p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                            >
                                <X className="w-5 h-5 text-text-secondary" />
                            </button>
                        </div>

                        <div className="relative mb-4">
                            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-text-tertiary" />
                            <input
                                type="text"
                                placeholder="Search by name or paste address"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                className="w-full pl-10 pr-4 py-3 bg-background-primary border border-border-primary rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-uniswap-pink"
                            />
                        </div>

                        <div className="space-y-2 max-h-64 overflow-y-auto">
                            {filteredTokens.map((token) => (
                                <button
                                    key={token.address}
                                    onClick={() => {
                                        onSelect(token);
                                        onClose();
                                    }}
                                    className={clsx(
                                        "w-full flex items-center space-x-3 p-3 rounded-xl transition-colors",
                                        selectedToken?.address === token.address
                                            ? "bg-uniswap-pink/10 border border-uniswap-pink"
                                            : "hover:bg-background-tertiary"
                                    )}
                                >
                                    <img
                                        src={token.logoURI}
                                        alt={token.symbol}
                                        className="w-8 h-8 rounded-full"
                                        onError={(e) => {
                                            e.currentTarget.style.display = 'none';
                                        }}
                                    />
                                    <div className="flex-1 text-left">
                                        <p className="font-medium text-text-primary">{token.symbol}</p>
                                        <p className="text-sm text-text-secondary">{token.name}</p>
                                    </div>
                                    {selectedToken?.address === token.address && (
                                        <CheckCircle className="w-5 h-5 text-uniswap-pink" />
                                    )}
                                </button>
                            ))}
                        </div>
                    </motion.div>
                </motion.div>
            )}
        </AnimatePresence>
    );
}

export default function EnhancedSwapInterface() {
    const { address, isConnected } = useAccount();
    const [swapState, setSwapState] = useState<SwapState>({
        inputToken: SUPPORTED_TOKENS[0],
        outputToken: SUPPORTED_TOKENS[1],
        inputAmount: '',
        outputAmount: '',
        slippageTolerance: 0.5,
        deadline: 20,
        gasOptimization: true,
        routeOptimization: true,
    });

    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [showTokenSelector, setShowTokenSelector] = useState<'input' | 'output' | null>(null);
    const [showSettings, setShowSettings] = useState(false);

    // Get input token balance
    const { data: inputBalance } = useBalance({
        address,
        token: swapState.inputToken?.address !== '0x0000000000000000000000000000000000000000'
            ? swapState.inputToken?.address as `0x${string}`
            : undefined,
    });

    // Calculate price impact and gas savings
    const priceImpact = useMemo(() => {
        if (!swapState.inputAmount || !swapState.outputAmount) return 0;
        return Math.random() * 2; // 0-2% price impact
    }, [swapState.inputAmount, swapState.outputAmount]);

    const gasSavings = useMemo(() => {
        if (!swapState.gasOptimization) return 0;
        return Math.random() * 80; // 0-80% gas savings
    }, [swapState.gasOptimization]);

    const handleInputChange = useCallback((value: string) => {
        setSwapState(prev => ({
            ...prev,
            inputAmount: value,
            outputAmount: value ? (parseFloat(value) * 1.5).toFixed(6) : '', // Mock calculation
        }));
        setError(null);
    }, []);

    const handleTokenSwap = useCallback(() => {
        setSwapState(prev => ({
            ...prev,
            inputToken: prev.outputToken,
            outputToken: prev.inputToken,
            inputAmount: prev.outputAmount,
            outputAmount: prev.inputAmount,
        }));
    }, []);

    const handleSwap = useCallback(async () => {
        if (!isConnected) {
            setError('Please connect your wallet');
            return;
        }

        if (!swapState.inputAmount || !swapState.outputAmount) {
            setError('Please enter an amount');
            return;
        }

        setIsLoading(true);
        setError(null);

        try {
            // Mock swap execution - replace with actual swap logic
            await new Promise(resolve => setTimeout(resolve, 2000));

            // Success - reset form
            setSwapState(prev => ({
                ...prev,
                inputAmount: '',
                outputAmount: '',
            }));
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Swap failed');
        } finally {
            setIsLoading(false);
        }
    }, [isConnected, swapState.inputAmount, swapState.outputAmount]);

    const isSwapDisabled = !isConnected || !swapState.inputAmount || isLoading;

    return (
        <div className="w-full max-w-lg mx-auto">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-background-secondary rounded-2xl border border-border-primary p-6 space-y-4"
            >
                {/* Header */}
                <div className="flex items-center justify-between">
                    <h2 className="text-xl font-semibold text-text-primary">Swap</h2>
                    <button
                        onClick={() => setShowSettings(!showSettings)}
                        className="p-2 hover:bg-background-tertiary rounded-xl transition-colors"
                    >
                        <Settings className="w-5 h-5 text-text-secondary" />
                    </button>
                </div>

                {/* Settings Panel */}
                <AnimatePresence>
                    {showSettings && (
                        <motion.div
                            initial={{ opacity: 0, height: 0 }}
                            animate={{ opacity: 1, height: 'auto' }}
                            exit={{ opacity: 0, height: 0 }}
                            className="bg-background-primary rounded-xl p-4 space-y-4"
                        >
                            <div className="space-y-2">
                                <label className="text-sm font-medium text-text-secondary">Slippage Tolerance</label>
                                <div className="flex space-x-2">
                                    {[0.1, 0.5, 1.0].map((value) => (
                                        <button
                                            key={value}
                                            onClick={() => setSwapState(prev => ({ ...prev, slippageTolerance: value }))}
                                            className={clsx(
                                                "px-3 py-1 rounded-lg text-sm font-medium transition-colors",
                                                swapState.slippageTolerance === value
                                                    ? "bg-uniswap-pink text-white"
                                                    : "bg-background-tertiary text-text-secondary hover:text-text-primary"
                                            )}
                                        >
                                            {value}%
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div className="space-y-2">
                                <label className="text-sm font-medium text-text-secondary">Transaction Deadline</label>
                                <input
                                    type="number"
                                    value={swapState.deadline}
                                    onChange={(e) => setSwapState(prev => ({ ...prev, deadline: parseInt(e.target.value) || 20 }))}
                                    className="w-full px-3 py-2 bg-background-tertiary border border-border-primary rounded-lg text-text-primary focus:outline-none focus:border-uniswap-pink"
                                    placeholder="20"
                                />
                                <span className="text-xs text-text-tertiary">minutes</span>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Input Token */}
                <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm text-text-secondary">
                        <span>You pay</span>
                        {inputBalance && (
                            <button
                                onClick={() => handleInputChange(formatUnits(inputBalance.value, inputBalance.decimals))}
                                className="text-uniswap-pink hover:text-uniswap-pink/80 transition-colors"
                            >
                                Balance: {formatUnits(inputBalance.value, inputBalance.decimals)}
                            </button>
                        )}
                    </div>
                    <div className="flex items-center space-x-3 p-4 bg-background-primary rounded-xl border border-border-primary">
                        <div className="flex-1">
                            <input
                                type="number"
                                placeholder="0.0"
                                value={swapState.inputAmount}
                                onChange={(e) => handleInputChange(e.target.value)}
                                className="w-full bg-transparent text-2xl font-medium text-text-primary placeholder-text-tertiary outline-none"
                            />
                        </div>
                        <button
                            onClick={() => setShowTokenSelector('input')}
                            className="flex items-center space-x-2 px-3 py-2 bg-background-tertiary rounded-lg hover:bg-border-primary transition-colors"
                        >
                            {swapState.inputToken?.logoURI && (
                                <img
                                    src={swapState.inputToken.logoURI}
                                    alt={swapState.inputToken.symbol}
                                    className="w-6 h-6 rounded-full"
                                />
                            )}
                            <span className="font-medium text-text-primary">{swapState.inputToken?.symbol}</span>
                            <ChevronDown className="w-4 h-4 text-text-secondary" />
                        </button>
                    </div>
                </div>

                {/* Swap Button */}
                <div className="flex justify-center">
                    <button
                        onClick={handleTokenSwap}
                        className="p-2 bg-background-tertiary rounded-xl hover:bg-border-primary transition-colors"
                    >
                        <ArrowUpDown className="w-5 h-5 text-text-secondary" />
                    </button>
                </div>

                {/* Output Token */}
                <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm text-text-secondary">
                        <span>You receive</span>
                        <span>≈ ${swapState.outputAmount ? (parseFloat(swapState.outputAmount) * 2000).toFixed(2) : '0.00'}</span>
                    </div>
                    <div className="flex items-center space-x-3 p-4 bg-background-primary rounded-xl border border-border-primary">
                        <div className="flex-1">
                            <input
                                type="number"
                                placeholder="0.0"
                                value={swapState.outputAmount}
                                readOnly
                                className="w-full bg-transparent text-2xl font-medium text-text-primary placeholder-text-tertiary outline-none"
                            />
                        </div>
                        <button
                            onClick={() => setShowTokenSelector('output')}
                            className="flex items-center space-x-2 px-3 py-2 bg-background-tertiary rounded-lg hover:bg-border-primary transition-colors"
                        >
                            {swapState.outputToken?.logoURI && (
                                <img
                                    src={swapState.outputToken.logoURI}
                                    alt={swapState.outputToken.symbol}
                                    className="w-6 h-6 rounded-full"
                                />
                            )}
                            <span className="font-medium text-text-primary">{swapState.outputToken?.symbol}</span>
                            <ChevronDown className="w-4 h-4 text-text-secondary" />
                        </button>
                    </div>
                </div>

                {/* Swap Details */}
                {swapState.inputAmount && (
                    <motion.div
                        initial={{ opacity: 0, height: 0 }}
                        animate={{ opacity: 1, height: 'auto' }}
                        className="bg-background-primary rounded-xl p-4 space-y-3"
                    >
                        <div className="flex items-center justify-between text-sm">
                            <span className="text-text-secondary">Price Impact</span>
                            <span className={clsx(
                                "font-medium",
                                priceImpact < 1 ? "text-uniswap-green" :
                                    priceImpact < 3 ? "text-uniswap-yellow" : "text-uniswap-pink"
                            )}>
                                {priceImpact.toFixed(2)}%
                            </span>
                        </div>

                        <div className="flex items-center justify-between text-sm">
                            <span className="text-text-secondary">Network Fee</span>
                            <span className="text-text-primary">~$12.50</span>
                        </div>

                        {swapState.gasOptimization && (
                            <div className="flex items-center justify-between text-sm">
                                <span className="text-text-secondary">Gas Savings</span>
                                <span className="text-uniswap-green font-medium">~{gasSavings.toFixed(0)}%</span>
                            </div>
                        )}

                        <div className="flex items-center justify-between text-sm">
                            <span className="text-text-secondary">Minimum received</span>
                            <span className="text-text-primary">
                                {swapState.outputAmount ?
                                    (parseFloat(swapState.outputAmount) * (1 - swapState.slippageTolerance / 100)).toFixed(6) :
                                    '0.0'
                                } {swapState.outputToken?.symbol}
                            </span>
                        </div>
                    </motion.div>
                )}

                {/* Error Message */}
                {error && (
                    <motion.div
                        initial={{ opacity: 0, y: -10 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="flex items-center space-x-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl"
                    >
                        <AlertTriangle className="w-5 h-5 text-red-500" />
                        <span className="text-sm text-red-500">{error}</span>
                    </motion.div>
                )}

                {/* Swap Button */}
                <button
                    onClick={handleSwap}
                    disabled={isSwapDisabled}
                    className={clsx(
                        "w-full py-4 rounded-xl font-semibold transition-all duration-300",
                        isSwapDisabled
                            ? "bg-background-tertiary text-text-tertiary cursor-not-allowed"
                            : "bg-uniswap-pink hover:bg-uniswap-pink/90 text-white hover:scale-[1.02] active:scale-[0.98]"
                    )}
                >
                    {isLoading ? (
                        <div className="flex items-center justify-center space-x-2">
                            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            <span>Swapping...</span>
                        </div>
                    ) : !isConnected ? (
                        "Connect Wallet"
                    ) : !swapState.inputAmount ? (
                        "Enter an amount"
                    ) : (
                        "Swap"
                    )}
                </button>

                {/* Gas Optimization Info */}
                <div className="flex items-center justify-center space-x-2 text-sm text-text-secondary">
                    <Zap className="w-4 h-4 text-uniswap-yellow" />
                    <span>Gas optimization automatically routes to the cheapest chain</span>
                </div>
            </motion.div>

            {/* Token Selector Modal */}
            <TokenSelector
                isOpen={showTokenSelector !== null}
                onClose={() => setShowTokenSelector(null)}
                onSelect={(token) => {
                    if (showTokenSelector === 'input') {
                        setSwapState(prev => ({ ...prev, inputToken: token }));
                    } else {
                        setSwapState(prev => ({ ...prev, outputToken: token }));
                    }
                }}
                selectedToken={showTokenSelector === 'input' ? swapState.inputToken : swapState.outputToken}
            />
        </div>
    );
} 