import { ConnectButton } from '@rainbow-me/rainbowkit';
import { motion } from 'framer-motion';
import { Wallet, AlertTriangle } from 'lucide-react';

export function ConnectWallet() {
    return (
        <ConnectButton.Custom>
            {({
                account,
                chain,
                openAccountModal,
                openChainModal,
                openConnectModal,
                authenticationStatus,
                mounted,
            }) => {
                const ready = mounted && authenticationStatus !== 'loading';
                const connected =
                    ready &&
                    account &&
                    chain &&
                    (!authenticationStatus ||
                        authenticationStatus === 'authenticated');

                return (
                    <div
                        {...(!ready && {
                            'aria-hidden': true,
                            style: {
                                opacity: 0,
                                pointerEvents: 'none',
                                userSelect: 'none',
                            },
                        })}
                    >
                        {(() => {
                            if (!connected) {
                                return (
                                    <motion.button
                                        whileHover={{ scale: 1.02 }}
                                        whileTap={{ scale: 0.98 }}
                                        onClick={openConnectModal}
                                        type="button"
                                        className="bg-uniswap-pink hover:bg-uniswap-pink/90 text-white font-semibold py-3 px-6 rounded-xl transition-all duration-300 flex items-center space-x-2"
                                    >
                                        <Wallet className="w-4 h-4" />
                                        <span>Connect Wallet</span>
                                    </motion.button>
                                );
                            }

                            if (chain.unsupported) {
                                return (
                                    <motion.button
                                        whileHover={{ scale: 1.02 }}
                                        whileTap={{ scale: 0.98 }}
                                        onClick={openChainModal}
                                        type="button"
                                        className="bg-red-500 hover:bg-red-600 text-white font-semibold py-3 px-6 rounded-xl transition-all duration-300 flex items-center space-x-2 border border-red-400 hover:border-red-300"
                                    >
                                        <AlertTriangle className="w-4 h-4" />
                                        <span>Wrong network</span>
                                    </motion.button>
                                );
                            }

                            return (
                                <div className="flex items-center space-x-2">
                                    <motion.button
                                        whileHover={{ scale: 1.02 }}
                                        whileTap={{ scale: 0.98 }}
                                        onClick={openChainModal}
                                        type="button"
                                        className="bg-background-tertiary hover:bg-border-primary text-text-primary font-semibold py-3 px-4 rounded-xl transition-all duration-300 flex items-center space-x-2 border border-border-primary"
                                    >
                                        {chain.hasIcon && (
                                            <div
                                                style={{
                                                    background: chain.iconBackground,
                                                    width: 20,
                                                    height: 20,
                                                    borderRadius: 999,
                                                    overflow: 'hidden',
                                                }}
                                            >
                                                {chain.iconUrl && (
                                                    <img
                                                        alt={chain.name ?? 'Chain icon'}
                                                        src={chain.iconUrl}
                                                        style={{ width: 20, height: 20 }}
                                                    />
                                                )}
                                            </div>
                                        )}
                                        <span className="text-sm font-medium">{chain.name}</span>
                                    </motion.button>

                                    <motion.button
                                        whileHover={{ scale: 1.02 }}
                                        whileTap={{ scale: 0.98 }}
                                        onClick={openAccountModal}
                                        type="button"
                                        className="bg-background-secondary border border-border-primary hover:border-border-secondary text-text-primary font-medium py-3 px-4 rounded-xl transition-all duration-300 flex items-center space-x-3"
                                    >
                                        <div className="flex flex-col items-start">
                                            <span className="text-sm font-medium">
                                                {account.displayName}
                                            </span>
                                            {account.displayBalance && (
                                                <span className="text-xs text-text-secondary">
                                                    {account.displayBalance}
                                                </span>
                                            )}
                                        </div>
                                        <div className="w-2 h-2 bg-uniswap-green rounded-full animate-pulse"></div>
                                    </motion.button>
                                </div>
                            );
                        })()}
                    </div>
                );
            }}
        </ConnectButton.Custom>
    );
} 