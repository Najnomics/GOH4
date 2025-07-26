/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                // Include default gray palette for compatibility
                gray: {
                    50: '#f9fafb',
                    100: '#f3f4f6',
                    200: '#e5e7eb',
                    300: '#d1d5db',
                    400: '#9ca3af',
                    500: '#6b7280',
                    600: '#4b5563',
                    700: '#374151',
                    800: '#1f2937',
                    900: '#111827',
                    950: '#030712',
                },
                // Include default slate palette for compatibility
                slate: {
                    50: '#f8fafc',
                    100: '#f1f5f9',
                    200: '#e2e8f0',
                    300: '#cbd5e1',
                    400: '#94a3b8',
                    500: '#64748b',
                    600: '#475569',
                    700: '#334155',
                    800: '#1e293b',
                    900: '#0f172a',
                    950: '#020617',
                },
                // Uniswap-inspired colors
                uniswap: {
                    pink: '#FF007A',
                    purple: '#7B3F98',
                    blue: '#4C82FB',
                    green: '#40D395',
                    yellow: '#FEF2C0',
                },
                // Background colors
                background: {
                    primary: '#0D0E0F',
                    secondary: '#131518',
                    tertiary: '#1C1E21',
                    modal: 'rgba(13, 14, 15, 0.8)',
                },
                // Border colors
                border: {
                    primary: '#2C2E32',
                    secondary: '#40444F',
                    accent: '#FF007A',
                },
                // Text colors
                text: {
                    primary: '#FFFFFF',
                    secondary: '#B4B4B4',
                    tertiary: '#7A7A7A',
                }
            },
            fontFamily: {
                sans: ['Inter', 'system-ui', 'sans-serif'],
                mono: ['Fira Code', 'monospace'],
            },
            animation: {
                'fade-in': 'fadeIn 0.5s ease-in-out',
                'slide-up': 'slideUp 0.3s ease-out',
                'slide-down': 'slideDown 0.3s ease-out',
                'scale-in': 'scaleIn 0.2s ease-out',
                'shimmer': 'shimmer 2s linear infinite',
                'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                'bounce-subtle': 'bounceSubtle 1s ease-in-out infinite',
                'glow': 'glow 2s ease-in-out infinite alternate',
            },
            keyframes: {
                fadeIn: {
                    '0%': { opacity: '0' },
                    '100%': { opacity: '1' },
                },
                slideUp: {
                    '0%': { transform: 'translateY(10px)', opacity: '0' },
                    '100%': { transform: 'translateY(0)', opacity: '1' },
                },
                slideDown: {
                    '0%': { transform: 'translateY(-10px)', opacity: '0' },
                    '100%': { transform: 'translateY(0)', opacity: '1' },
                },
                scaleIn: {
                    '0%': { transform: 'scale(0.95)', opacity: '0' },
                    '100%': { transform: 'scale(1)', opacity: '1' },
                },
                shimmer: {
                    '0%': { transform: 'translateX(-100%)' },
                    '100%': { transform: 'translateX(100%)' },
                },
                bounceSubtle: {
                    '0%, 100%': { transform: 'translateY(-5%)' },
                    '50%': { transform: 'translateY(0)' },
                },
                glow: {
                    '0%': { boxShadow: '0 0 5px rgba(255, 0, 122, 0.5)' },
                    '100%': { boxShadow: '0 0 20px rgba(255, 0, 122, 0.8)' },
                },
            },
            backdropBlur: {
                xs: '2px',
            },
            boxShadow: {
                'glow-sm': '0 0 10px rgba(255, 0, 122, 0.3)',
                'glow-md': '0 0 20px rgba(255, 0, 122, 0.4)',
                'glow-lg': '0 0 30px rgba(255, 0, 122, 0.5)',
                'inner-glow': 'inset 0 0 10px rgba(255, 0, 122, 0.2)',
            },
            backgroundImage: {
                'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
                'gradient-conic': 'conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))',
                'mesh-gradient': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                'shimmer': 'linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent)',
            },
        },
    },
    plugins: [
        require('@tailwindcss/forms'),
    ],
} 