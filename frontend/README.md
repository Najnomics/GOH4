# 🦄 GasOpt Frontend - Vite + React

A modern, fast frontend for the Gas Optimization Hook project, built with Vite, React, and TypeScript, inspired by Uniswap's interface design patterns.

## ⚡ Why Vite?

- **Lightning Fast**: Instant hot module replacement (HMR)
- **Optimized Builds**: Faster build times with esbuild
- **Modern Tooling**: Built-in TypeScript and JSX support
- **Better DX**: Improved development experience
- **Smaller Bundle**: More efficient bundling

## ✨ Features

### 🎯 Core Functionality
- **Smart Swap Interface**: Uniswap-style token swapping with gas optimization
- **Cross-Chain Optimization**: Automatic routing to the most cost-effective chains
- **Real-time Gas Tracking**: Live gas price monitoring across multiple chains
- **Wallet Integration**: Seamless wallet connection with RainbowKit
- **Transaction Analytics**: Detailed savings and performance metrics

### 🎨 UI/UX Features
- **Uniswap-Inspired Design**: Clean, modern interface following Uniswap's design patterns
- **Responsive Layout**: Mobile-first design that works on all devices
- **Smooth Animations**: Framer Motion powered transitions and micro-interactions
- **Dark Theme**: Professional dark theme optimized for DeFi applications
- **Accessibility**: WCAG compliant with proper ARIA labels and keyboard navigation

## 🏗️ Architecture

### Tech Stack
- **Vite**: Fast build tool and dev server
- **React 18**: Latest React with concurrent features
- **TypeScript**: Full type safety
- **Tailwind CSS**: Utility-first CSS framework
- **Framer Motion**: Smooth animations
- **RainbowKit**: Modern wallet connection UI
- **Wagmi**: React hooks for Ethereum
- **Viem**: Type-safe Ethereum client

### Project Structure
```
src/
├── main.tsx                 # Application entry point
├── App.tsx                  # Main application component
├── index.css               # Global styles and Tailwind imports
├── components/
│   ├── SwapInterface.tsx    # Main swap interface component
│   ├── GasOptimizationPanel.tsx # Gas optimization metrics panel
│   └── ConnectWallet.tsx    # Wallet connection component
├── lib/
│   └── wagmi.ts            # Wagmi configuration
├── hooks/                  # Custom React hooks
└── types/                  # TypeScript type definitions
```

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ 
- npm or yarn
- WalletConnect Project ID

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd frontend
```

2. **Install dependencies**
```bash
npm install
```

3. **Environment Setup**
The `.env` file is already configured with your WalletConnect project ID:
```env
VITE_WALLET_CONNECT_PROJECT_ID=025acf6134d38681e310bb7e00022000
```

4. **Start development server**
```bash
npm run dev
```

The application will be available at `http://localhost:3000`

## 🎨 Design System

### Color Palette
```css
/* Uniswap-inspired colors */
--uniswap-pink: #FF007A
--uniswap-purple: #7B3F98
--uniswap-blue: #4C82FB
--uniswap-green: #40D395
--uniswap-yellow: #FEF2C0

/* Background colors */
--background-primary: #0D0E0F
--background-secondary: #131518
--background-tertiary: #1C1E21

/* Text colors */
--text-primary: #FFFFFF
--text-secondary: #B4B4B4
--text-tertiary: #7A7A7A

/* Border colors */
--border-primary: #2C2E32
--border-secondary: #40444F
```

### Typography
- **Primary Font**: Inter (system fallback)
- **Monospace Font**: Fira Code (for addresses and numbers)

## 🔧 Configuration

### Vite Configuration
```typescript
// vite.config.ts
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
})
```

### Tailwind CSS
- Custom color palette
- Uniswap-inspired design tokens
- Responsive breakpoints
- Custom animations and transitions

### Wallet Integration
- **RainbowKit**: Modern wallet connection UI
- **Wagmi**: React hooks for Ethereum
- **WalletConnect**: Multi-wallet support
- **Supported Wallets**: MetaMask, Coinbase Wallet, WalletConnect, and more

## 📱 Responsive Design

### Breakpoints
- **Mobile**: < 768px
- **Tablet**: 768px - 1024px
- **Desktop**: > 1024px

### Mobile Features
- Collapsible navigation menu
- Touch-optimized interfaces
- Swipe gestures for token selection
- Optimized keyboard input

## 🔒 Security Features

- **Input Validation**: Comprehensive form validation
- **Error Handling**: User-friendly error messages
- **Transaction Confirmation**: Clear transaction details before execution
- **Slippage Protection**: Configurable slippage tolerance
- **Price Impact Warnings**: Visual indicators for high-impact trades

## 🧪 Testing

### Component Testing
```bash
npm run test
```

### E2E Testing
```bash
npm run test:e2e
```

### Performance Testing
```bash
npm run build
npm run preview
```

## 📊 Performance Optimizations

### Vite Optimizations
- **Fast HMR**: Instant hot module replacement
- **Tree Shaking**: Automatic dead code elimination
- **Code Splitting**: Automatic chunk splitting
- **Pre-bundling**: Optimized dependency pre-bundling

### Bundle Size
- Dynamic imports for heavy components
- Tree shaking for unused code
- Optimized image loading
- Code splitting by routes

### Runtime Performance
- Memoized expensive calculations
- Debounced user inputs
- Optimized re-renders
- Efficient state management

## 🌐 Browser Support

- **Chrome**: 90+
- **Firefox**: 88+
- **Safari**: 14+
- **Edge**: 90+

## 📦 Build & Deploy

### Development
```bash
npm run dev
```

### Production Build
```bash
npm run build
```

### Preview Production Build
```bash
npm run preview
```

### Deploy to Vercel
```bash
npm run build
# Deploy dist/ folder to your hosting provider
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- **TypeScript**: Strict mode enabled
- **ESLint**: Airbnb configuration
- **Prettier**: Consistent formatting
- **Husky**: Pre-commit hooks

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- **Uniswap Labs** for the innovative interface design patterns
- **RainbowKit** for the excellent wallet integration
- **Vite** for the fast build tool
- **Tailwind CSS** for the utility-first CSS framework
- **Framer Motion** for smooth animations

## 🔄 Migration from Next.js

### Key Changes
- **Build Tool**: Next.js → Vite
- **Routing**: Next.js App Router → React Router (if needed)
- **Environment Variables**: `NEXT_PUBLIC_` → `VITE_`
- **Import Meta**: `process.env` → `import.meta.env`
- **Build Output**: `.next` → `dist`

### Benefits
- **Faster Development**: Instant HMR
- **Smaller Bundle**: More efficient bundling
- **Better DX**: Improved development experience
- **Modern Tooling**: Latest build tool features

---

**Built with ❤️ for the Uniswap Hook Incubator Hackathon** 🦄⚡ 