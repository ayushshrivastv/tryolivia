/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import Image from 'next/image';
import Link from 'next/link';

export default function SignInPage() {
  return (
    <div className="grid w-screen min-h-screen max-w-[1600px] gap-4 self-center bg-background px-6 lg:px-20">
      <header className="h-[4.5rem] grid w-full items-center bg-background">
        <nav className="flex items-center justify-between" aria-label="Global">
          <Link
            href="/"
            className="flex items-center gap-2"
            tabIndex={-1}
            title="Olivia | Privacy-First Prediction Markets"
          >
            <Image src={'/Arcium Icon.png'} height={32} width={32} alt={'Arcium Icon'} />
            <Image src={'/Arcium logo.png'} height={32} width={120} alt={'Arcium Logo'} />
          </Link>
        </nav>
      </header>

      <div className="hide-scrollbar min-h-[calc(100vh-7rem)]">
        <div className="flex h-full w-full items-center justify-center">
          <div className="w-full max-w-5xl px-4">
            <video
              src="/Arcium Clip 1 .mp4"
              controls
              autoPlay
              loop
              muted
              playsInline
              className="w-full rounded-3xl shadow-2xl"
              style={{
                width: '100%',
                maxWidth: '1280px',
                height: 'auto',
                aspectRatio: '16/9',
                borderRadius: '24px',
                boxShadow: '0 20px 60px rgba(0, 0, 0, 0.5)',
              }}
            >
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      </div>
    </div>
  );
}
