import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    server: {
        port: 3000,
        host: true,
    },
    build: {
        outDir: 'dist',
        sourcemap: true,
        rollupOptions: {
            output: {
                manualChunks: {
                    vendor: ['react', 'react-dom'],
                    wallet: ['@rainbow-me/rainbowkit', 'wagmi', 'viem'],
                    ui: ['framer-motion', 'lucide-react'],
                },
            },
        },
    },
    optimizeDeps: {
        include: ['react', 'react-dom', '@rainbow-me/rainbowkit', 'wagmi', 'viem'],
    },
}) 