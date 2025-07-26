import {
    Twitter,
    MessageCircle,
    Github,
    ExternalLink,
    Mail,
    Shield,
    Zap,
    TrendingUp
} from 'lucide-react';

export default function EnhancedFooter() {
    const footerSections = [
        {
            title: 'Product',
            links: [
                { label: 'Swap', href: '#', external: false },
                { label: 'Gas Optimization', href: '#', external: false },
                { label: 'Analytics', href: '#', external: false },
                { label: 'API', href: '#', external: true },
                { label: 'SDK', href: '#', external: true },
            ]
        },
        {
            title: 'Developers',
            links: [
                { label: 'Documentation', href: '#', external: true },
                { label: 'GitHub', href: '#', external: true },
                { label: 'Bug Bounty', href: '#', external: true },
                { label: 'Audit Reports', href: '#', external: true },
                { label: 'Careers', href: '#', external: true },
            ]
        },
        {
            title: 'Support',
            links: [
                { label: 'Help Center', href: '#', external: false },
                { label: 'Discord', href: '#', external: true },
                { label: 'Twitter', href: '#', external: true },
                { label: 'Blog', href: '#', external: true },
                { label: 'Contact', href: '#', external: false },
            ]
        },
        {
            title: 'Legal',
            links: [
                { label: 'Privacy Policy', href: '#', external: false },
                { label: 'Terms of Service', href: '#', external: false },
                { label: 'Cookie Policy', href: '#', external: false },
                { label: 'Disclaimers', href: '#', external: false },
            ]
        }
    ];

    const socialLinks = [
        { icon: Twitter, href: '#', label: 'Twitter' },
        { icon: MessageCircle, href: '#', label: 'Discord' },
        { icon: Github, href: '#', label: 'GitHub' },
        { icon: Mail, href: '#', label: 'Email' },
    ];

    const features = [
        { icon: Zap, label: 'Gas Optimization', description: 'Save up to 80% on gas fees' },
        { icon: Shield, label: 'MEV Protection', description: 'Protect against front-running' },
        { icon: TrendingUp, label: 'Multi-Chain', description: 'Trade across 6+ networks' },
    ];

    return (
        <footer className="border-t border-border-primary bg-background-secondary/50">
            {/* Main Footer */}
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
                {/* Top Section */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mb-12">
                    {/* Brand Section */}
                    <div className="space-y-6">
                        <div className="flex items-center space-x-3">
                            <div className="w-10 h-10 bg-gradient-to-br from-uniswap-pink to-uniswap-purple rounded-xl flex items-center justify-center">
                                <span className="text-white font-bold text-lg">G</span>
                            </div>
                            <div>
                                <span className="text-2xl font-bold text-text-primary">GasOpt</span>
                                <p className="text-sm text-text-secondary">Gas Optimization Hook</p>
                            </div>
                        </div>

                        <p className="text-text-secondary max-w-md">
                            Intelligent gas optimization for DeFi swaps across multiple chains.
                            Save money, time, and gas with our advanced routing technology.
                        </p>

                        {/* Features */}
                        <div className="space-y-3">
                            {features.map((feature) => {
                                const Icon = feature.icon;
                                return (
                                    <div key={feature.label} className="flex items-center space-x-3">
                                        <div className="p-1.5 bg-uniswap-pink/10 rounded-lg">
                                            <Icon className="w-4 h-4 text-uniswap-pink" />
                                        </div>
                                        <div>
                                            <p className="text-sm font-medium text-text-primary">{feature.label}</p>
                                            <p className="text-xs text-text-secondary">{feature.description}</p>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* Social Links */}
                        <div className="flex items-center space-x-4">
                            {socialLinks.map((social) => {
                                const Icon = social.icon;
                                return (
                                    <a
                                        key={social.label}
                                        href={social.href}
                                        className="p-2 bg-background-tertiary hover:bg-border-primary rounded-xl transition-colors group"
                                        aria-label={social.label}
                                    >
                                        <Icon className="w-5 h-5 text-text-secondary group-hover:text-text-primary transition-colors" />
                                    </a>
                                );
                            })}
                        </div>
                    </div>

                    {/* Links Section */}
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
                        {footerSections.map((section) => (
                            <div key={section.title} className="space-y-4">
                                <h4 className="font-semibold text-text-primary">{section.title}</h4>
                                <ul className="space-y-2">
                                    {section.links.map((link) => (
                                        <li key={link.label}>
                                            <a
                                                href={link.href}
                                                className="text-sm text-text-secondary hover:text-text-primary transition-colors flex items-center space-x-1 group"
                                            >
                                                <span>{link.label}</span>
                                                {link.external && (
                                                    <ExternalLink className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                                                )}
                                            </a>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Newsletter Signup */}
                <div className="bg-background-primary rounded-2xl border border-border-primary p-6 mb-8">
                    <div className="max-w-md">
                        <h4 className="font-semibold text-text-primary mb-2">Stay Updated</h4>
                        <p className="text-sm text-text-secondary mb-4">
                            Get the latest updates on gas optimization and new features.
                        </p>
                        <div className="flex space-x-3">
                            <input
                                type="email"
                                placeholder="Enter your email"
                                className="flex-1 px-3 py-2 bg-background-tertiary border border-border-primary rounded-lg text-text-primary placeholder-text-tertiary focus:outline-none focus:border-uniswap-pink"
                            />
                            <button className="px-4 py-2 bg-uniswap-pink hover:bg-uniswap-pink/90 text-white font-medium rounded-lg transition-colors">
                                Subscribe
                            </button>
                        </div>
                    </div>
                </div>

                {/* Bottom Section */}
                <div className="flex flex-col md:flex-row items-center justify-between space-y-4 md:space-y-0">
                    <div className="flex items-center space-x-6 text-sm text-text-secondary">
                        <span>© 2024 GasOpt. All rights reserved.</span>
                        <span>•</span>
                        <span>Built with ❤️ for the Uniswap Hook Incubator Hackathon</span>
                    </div>

                    <div className="flex items-center space-x-6 text-sm">
                        <span className="text-text-secondary">Version 1.0.0</span>
                        <span className="text-uniswap-green">●</span>
                        <span className="text-uniswap-green">All systems operational</span>
                    </div>
                </div>
            </div>

            {/* Mobile App Banner */}
            <div className="border-t border-border-primary bg-background-primary">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <h4 className="font-semibold text-text-primary mb-1">Trade on the go</h4>
                            <p className="text-sm text-text-secondary">Download our mobile app for the best experience</p>
                        </div>
                        <div className="flex items-center space-x-3">
                            <button className="px-4 py-2 bg-background-tertiary hover:bg-border-primary text-text-primary font-medium rounded-lg transition-colors">
                                Coming Soon
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </footer>
    );
} 