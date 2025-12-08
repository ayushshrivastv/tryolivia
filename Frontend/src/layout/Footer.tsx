/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

import Link from 'next/link';

export function Footer() {
  return (
    <footer className="border-t border-border/10 pt-8 pb-6 w-full" style={{ background: 'transparent' }}>
      <div className="container mx-auto px-4">
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-8 mb-8 max-w-6xl mx-auto">
          <div className="lg:col-span-1">
            <h4 className="text-sm font-medium text-white mb-4" style={{ textShadow: '0 3px 8px rgba(0,0,0,1), 2px 2px 4px rgba(0,0,0,0.9)' }}>
              Olivia
            </h4>
            <p className="text-sm text-gray-100 mb-2" style={{ textShadow: '0 2px 6px rgba(0,0,0,1), 1px 1px 3px rgba(0,0,0,0.9)' }}>
              Privacy-First Prediction Markets
            </p>
          </div>

          <div className="lg:col-span-1">
            <h4 className="text-sm font-medium text-white mb-4" style={{ textShadow: '0 2px 4px rgba(0,0,0,0.8)' }}>
              About
            </h4>
            <FooterLink href="/about">About Olivia</FooterLink>
            <FooterLink href="/how-it-works">How It Works</FooterLink>
          </div>

          <div className="lg:col-span-1">
            <h4 className="text-sm font-medium text-white mb-4" style={{ textShadow: '0 3px 8px rgba(0,0,0,1), 2px 2px 4px rgba(0,0,0,0.9)' }}>Markets</h4>
            <FooterLink href="/markets">All Markets</FooterLink>
            <FooterLink href="/markets/active">Active Events</FooterLink>
          </div>

          <div className="lg:col-span-1">
            <h4 className="text-sm font-medium text-white mb-4" style={{ textShadow: '0 3px 8px rgba(0,0,0,1), 2px 2px 4px rgba(0,0,0,0.9)' }}>Support</h4>
            <FooterLink href="/help">Help Center</FooterLink>
            <FooterLink href="/faqs">FAQ</FooterLink>
          </div>

          <div className="lg:col-span-1">
            <h4 className="text-sm font-medium text-white mb-4" style={{ textShadow: '0 3px 8px rgba(0,0,0,1), 2px 2px 4px rgba(0,0,0,0.9)' }}>Portfolio</h4>
            <FooterLink href="/docs">Documentation</FooterLink>
            <FooterLink href="/blog">Blog</FooterLink>
          </div>

        </div>

        <div className="flex flex-col justify-center items-center pt-6 border-t border-border/10 gap-3">
          <div className="text-xs text-gray-400 text-center max-w-3xl px-4" style={{ textShadow: '0 0 10px rgba(0,0,0,1), 0 0 20px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)' }}>
            <p>
              This project is not affiliated with, endorsed by, or connected to Arcium. 
              Olivia uses Arcium technology for privacy-preserving prediction markets.
            </p>
          </div>
          <div className="text-sm text-white" style={{ textShadow: '0 0 10px rgba(0,0,0,1), 0 0 20px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)', WebkitTextStroke: '0.3px rgba(0,0,0,0.9)' }}>
            © 2025 Ayush Srivastava, All rights reserved.
          </div>
        </div>
      </div>
    </footer>
  );
}

interface FooterLinkProps {
  href: string;
  children: React.ReactNode;
}

function FooterLink({ href, children }: FooterLinkProps) {
  return (
    <Link
      href={href}
      className="block text-sm text-white transition-colors mb-2" style={{ textShadow: '0 0 10px rgba(0,0,0,1), 0 0 20px rgba(0,0,0,1), 1px  answering 4px rgba(0,0,0,1)', WebkitTextStroke: '0.3px rgba(0,0,0,0.9)' }}
    >
      {children}
    </Link>
  );
}
