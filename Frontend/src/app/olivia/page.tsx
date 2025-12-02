/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';

export default function SignInPage() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [showPlayButton, setShowPlayButton] = useState(true);

  useEffect(() => {
    const video = videoRef.current;
    if (video) {
      // Try to play on load
      video.play()
        .then(() => {
          setIsPlaying(true);
          setShowPlayButton(false);
        })
        .catch((error) => {
          console.log('Autoplay prevented, user interaction required:', error);
          setShowPlayButton(true);
        });

      // Handle play/pause events
      const handlePlay = () => {
        setIsPlaying(true);
        setShowPlayButton(false);
      };
      const handlePause = () => {
        setIsPlaying(false);
        setShowPlayButton(true);
      };

      video.addEventListener('play', handlePlay);
      video.addEventListener('pause', handlePause);

      return () => {
        video.removeEventListener('play', handlePlay);
        video.removeEventListener('pause', handlePause);
      };
    }
  }, []);

  const handleVideoClick = () => {
    const video = videoRef.current;
    if (video) {
      if (video.paused) {
        video.play().catch((error) => {
          console.error('Error playing video:', error);
        });
      } else {
        video.pause();
      }
    }
  };

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
          <div className="w-full max-w-5xl px-4 relative">
            <div 
              className="relative cursor-pointer"
              onClick={handleVideoClick}
            >
              <video
                ref={videoRef}
                src="/Arcium Clip 1 .mp4"
                controls
                autoPlay
                loop
                muted
                playsInline
                preload="auto"
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
              {showPlayButton && !isPlaying && (
                <div
                  className="absolute inset-0 flex items-center justify-center bg-black/30 rounded-3xl"
                  style={{
                    borderRadius: '24px',
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    const video = videoRef.current;
                    if (video) {
                      video.play().catch((error) => {
                        console.error('Error playing video:', error);
                      });
                    }
                  }}
                >
                  <div
                    className="w-20 h-20 flex items-center justify-center rounded-full bg-white/20 backdrop-blur-sm cursor-pointer hover:bg-white/30 transition-all"
                    style={{
                      border: '3px solid rgba(255, 255, 255, 0.5)',
                    }}
                  >
                    <svg
                      width="40"
                      height="40"
                      viewBox="0 0 24 24"
                      fill="white"
                      className="ml-1"
                    >
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
