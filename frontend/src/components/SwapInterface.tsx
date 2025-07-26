import { useState, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowUpDown, Settings, AlertTriangle, Zap, Info } from 'lucide-react';
import { useAccount, useBalance } from 'wagmi';
import { formatUnits } from 'viem';
import clsx from 'clsx';

interface Token {
    symbol: string;
    name: string;
    address: string;
    decimals: number;
}

interface SwapState {
    inputToken: Token | null;
    outputToken: Token | null;
    inputAmount: string;
    outputAmount: string;
    slippageTolerance: number;
    deadline: number;
    gasOptimization: boolean;
}

const SUPPORTED_TOKENS: Token[] = [
    { symbol: 'ETH', name: 'Ethereum', address: '0x0000000000000000000000000000000000000000', decimals: 18 },
    { symbol: 'USDC', name: 'USD Coin', address: '0xA0b86a33E6441b8c4C8C8C8C8C8C8C8C8C8C8C', decimals: 6 },
    { symbol: 'WETH', name: 'Wrapped Ether', address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', decimals: 18 },
    { symbol: 'DAI', name: 'Dai Stablecoin', address: '0x6B175474E89094C44Da98b954EedeAC495271d0F', decimals: 18 },
];

export default function SwapInterface() {
    const { address, isConnected } = useAccount();
    const [swapState, setSwapState] = useState<SwapState>({
        inputToken: SUPPORTED_TOKENS[0],
        outputToken: SUPPORTED_TOKENS[1],
        inputAmount: '',
        outputAmount: '',
        slippageTolerance: 0.5,
        deadline: 20,
        gasOptimization: true,
    });

    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

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
        // Mock calculation - replace with actual price impact logic
        return Math.random() * 2; // 0-2% price impact
    }, [swapState.inputAmount, swapState.outputAmount]);

    const gasSavings = useMemo(() => {
        if (!swapState.gasOptimization) return 0;
        // Mock calculation - replace with actual gas savings logic
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
        <div className="w-full max-w-md mx-auto">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-background-secondary rounded-2xl border border-border-primary p-6 space-y-4"
            >
                {/* Header */}
                <div className="flex items-center justify-between">
                    <h2 className="text-xl font-semibold text-text-primary">Swap</h2>
                    <button className="p-2 hover:bg-background-tertiary rounded-xl transition-colors">
                        <Settings className="w-5 h-5 text-text-secondary" />
                    </button>
                </div>

                {/* Input Token */}
                <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm text-text-secondary">
                        <span>You pay</span>
                        {inputBalance && (
                            <span>Balance: {formatUnits(inputBalance.value, inputBalance.decimals)}</span>
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
                        <button className="flex items-center space-x-2 px-3 py-2 bg-background-tertiary rounded-lg hover:bg-border-primary transition-colors">
                            <div className="w-6 h-6 bg-uniswap-blue rounded-full" />
                            <span className="font-medium text-text-primary">{swapState.inputToken?.symbol}</span>
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
                        <button className="flex items-center space-x-2 px-3 py-2 bg-background-tertiary rounded-lg hover:bg-border-primary transition-colors">
                            <div className="w-6 h-6 bg-uniswap-green rounded-full" />
                            <span className="font-medium text-text-primary">{swapState.outputToken?.symbol}</span>
                        </button>
                    </div>
                </div>

                {/* Gas Optimization Toggle */}
                <div className="flex items-center justify-between p-3 bg-background-tertiary rounded-xl">
                    <div className="flex items-center space-x-2">
                        <Zap className="w-4 h-4 text-uniswap-yellow" />
                        <span className="text-sm font-medium text-text-primary">Gas Optimization</span>
                    </div>
                    <button
                        onClick={() => setSwapState(prev => ({ ...prev, gasOptimization: !prev.gasOptimization }))}
                        className={clsx(
                            "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                            swapState.gasOptimization ? "bg-uniswap-green" : "bg-border-primary"
                        )}
                    >
                        <span
                            className={clsx(
                                "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                                swapState.gasOptimization ? "translate-x-6" : "translate-x-1"
                            )}
                        />
                    </button>
                </div>

                {/* Price Impact & Gas Savings */}
                <AnimatePresence>
                    {swapState.inputAmount && (
                        <motion.div
                            initial={{ opacity: 0, height: 0 }}
                            animate={{ opacity: 1, height: 'auto' }}
                            exit={{ opacity: 0, height: 0 }}
                            className="space-y-2 text-sm"
                        >
                            <div className="flex justify-between text-text-secondary">
                                <span>Price Impact</span>
                                <span className={priceImpact > 1 ? "text-uniswap-pink" : "text-text-secondary"}>
                                    {priceImpact.toFixed(2)}%
                                </span>
                            </div>
                            {swapState.gasOptimization && (
                                <div className="flex justify-between text-text-secondary">
                                    <span>Gas Savings</span>
                                    <span className="text-uniswap-green">{gasSavings.toFixed(0)}%</span>
                                </div>
                            )}
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Error Message */}
                <AnimatePresence>
                    {error && (
                        <motion.div
                            initial={{ opacity: 0, y: -10 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -10 }}
                            className="flex items-center space-x-2 p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400"
                        >
                            <AlertTriangle className="w-4 h-4" />
                            <span className="text-sm">{error}</span>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Swap Button */}
                <button
                    onClick={handleSwap}
                    disabled={isSwapDisabled}
                    className={clsx(
                        "w-full py-4 px-6 rounded-xl font-semibold transition-all",
                        isSwapDisabled
                            ? "bg-border-primary text-text-tertiary cursor-not-allowed"
                            : "bg-uniswap-pink text-white hover:bg-uniswap-pink/90 active:scale-95"
                    )}
                >
                    {isLoading ? (
                        <div className="flex items-center justify-center space-x-2">
                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            <span>Swapping...</span>
                        </div>
                    ) : !isConnected ? (
                        'Connect Wallet'
                    ) : !swapState.inputAmount ? (
                        'Enter an amount'
                    ) : (
                        'Swap'
                    )}
                </button>

                {/* Info */}
                <div className="flex items-center justify-center space-x-2 text-xs text-text-tertiary">
                    <Info className="w-3 h-3" />
                    <span>Gas optimization automatically routes to the cheapest chain</span>
                </div>
            </motion.div>
        </div>
    );
} 