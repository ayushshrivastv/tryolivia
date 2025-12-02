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
  const youtubePlayerRef = useRef<HTMLDivElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [showPlayButton, setShowPlayButton] = useState(true);
  const [videoError, setVideoError] = useState(false);
  const [autoPlayStarted, setAutoPlayStarted] = useState(false);
  
  // Use external video URL from env variable - initialized in useEffect to avoid hydration mismatch
  // Set NEXT_PUBLIC_VIDEO_URL in Vercel environment variables with your video URL
  const [videoSrc, setVideoSrc] = useState<string>('');
  const [isMounted, setIsMounted] = useState(false);

  // Check if URL is YouTube
  const isYouTube = videoSrc.includes('youtube.com') || videoSrc.includes('youtu.be');
  
  const [youtubeVideoId, setYoutubeVideoId] = useState<string>('');
  const [youtubePlayer, setYoutubePlayer] = useState<YTPlayer | null>(null);

  // Set video source after mount to avoid hydration mismatch
  useEffect(() => {
    setIsMounted(true);
    const videoUrl = process.env.NEXT_PUBLIC_VIDEO_URL || '';
    console.log('[Olivia Video] Environment variable:', videoUrl ? 'Set' : 'Missing');
    console.log('[Olivia Video] Video URL:', videoUrl || 'Not configured');
    
    if (!videoUrl) {
      console.warn('[Olivia Video] NEXT_PUBLIC_VIDEO_URL is not set. Please configure it in Vercel environment variables.');
    }
    
    setVideoSrc(videoUrl);
    // Start playing immediately if video is available (no delay)
    if (videoUrl) {
      setAutoPlayStarted(true);
      console.log('[Olivia Video] Auto-play started for:', videoUrl);
    }
  }, []);

  // Extract YouTube video ID
  useEffect(() => {
    if (isYouTube && videoSrc) {
      let videoId = '';
      if (videoSrc.includes('youtube.com/watch?v=')) {
        videoId = videoSrc.split('v=')[1]?.split('&')[0] || '';
      } else if (videoSrc.includes('youtu.be/')) {
        videoId = videoSrc.split('youtu.be/')[1]?.split('?')[0] || '';
      } else if (videoSrc.includes('youtube.com/embed/')) {
        videoId = videoSrc.split('embed/')[1]?.split('?')[0] || '';
      }
      
      if (videoId) {
        setYoutubeVideoId(videoId);
      }
    } else {
      setYoutubeVideoId('');
    }
  }, [videoSrc, isYouTube]);

  // Initialize YouTube IFrame API
  useEffect(() => {
    if (!isYouTube || !youtubeVideoId || !autoPlayStarted) {
      if (!isYouTube) console.log('[Olivia Video] Not a YouTube URL');
      if (!youtubeVideoId) console.log('[Olivia Video] YouTube video ID not extracted yet');
      if (!autoPlayStarted) console.log('[Olivia Video] Auto-play not started yet');
      return;
    }

    // Don't reinitialize if player already exists
    if (youtubePlayer) {
      console.log('[Olivia Video] YouTube player already initialized');
      return;
    }

    console.log('[Olivia Video] Initializing YouTube player for video ID:', youtubeVideoId);

    const loadYouTubeAPI = () => {
      if (!window.YT || !window.YT.Player) {
        console.warn('[Olivia Video] YouTube API not loaded yet');
        return;
      }
      
      if (!youtubePlayerRef.current) {
        console.warn('[Olivia Video] YouTube player container not found');
        return;
      }
      
      console.log('[Olivia Video] Creating YouTube player...');
      
      try {
        // Create YouTube player - API will create iframe for us
        // Video will start immediately with autoplay
        const player = new window.YT.Player(youtubePlayerRef.current, {
            videoId: youtubeVideoId,
            playerVars: {
              autoplay: 1, // Start playing immediately
              mute: 1,
              loop: 1,
              playlist: youtubeVideoId,
              controls: 1,
              modestbranding: 1,
              enablejsapi: 1,
            },
            events: {
              onReady: (event: YTOnReadyEvent) => {
                console.log('[Olivia Video] YouTube player ready');
                // Set quality: try 1440p60 first, fallback to 1080p
                try {
                  const qualityLevels = event.target.getAvailableQualityLevels();
                  console.log('[Olivia Video] Available qualities:', qualityLevels);
                  
                  // Try to set 1440p60 (hd1440) first, then 1080p (hd1080)
                  if (qualityLevels.includes('hd1440')) {
                    event.target.setPlaybackQuality('hd1440');
                    console.log('[Olivia Video] Set quality to 1440p60');
                  } else if (qualityLevels.includes('hd1080')) {
                    event.target.setPlaybackQuality('hd1080');
                    console.log('[Olivia Video] Set quality to 1080p');
                  } else if (qualityLevels.length > 0) {
                    // Fallback to highest available
                    event.target.setPlaybackQuality(qualityLevels[0]);
                    console.log('[Olivia Video] Set quality to highest available:', qualityLevels[0]);
                  }
                  // Video should already be playing with autoplay: 1, but ensure playback after quality change
                  try {
                    event.target.playVideo();
                  } catch (playError) {
                    console.warn('Could not start video playback:', playError);
                  }
                } catch (error) {
                  console.warn('Could not set quality:', error);
                  // Ensure playback continues even if quality setting fails
                  try {
                    event.target.playVideo();
                  } catch (playError) {
                    console.warn('Could not start video playback:', playError);
                  }
                }
              },
              onStateChange: (event: YTOnStateChangeEvent) => {
                if (window.YT && event.data === window.YT.PlayerState.PLAYING) {
                  setIsPlaying(true);
                  setShowPlayButton(false);
                } else if (window.YT && event.data === window.YT.PlayerState.PAUSED) {
                  setIsPlaying(false);
                }
              },
            },
          });
          setYoutubePlayer(player);
          console.log('[Olivia Video] YouTube player created successfully');
        } catch (error) {
          console.error('[Olivia Video] Error creating YouTube player:', error);
        }
    };

    // Load YouTube API script if not already loaded
    if (!window.YT) {
      console.log('[Olivia Video] Loading YouTube IFrame API...');
      // Set up the callback before loading the script
      window.onYouTubeIframeAPIReady = () => {
        console.log('[Olivia Video] YouTube API ready callback called');
        loadYouTubeAPI();
      };
      
      const script = document.createElement('script');
      script.src = 'https://www.youtube.com/iframe_api';
      script.async = true;
      script.onload = () => {
        console.log('[Olivia Video] YouTube API script loaded');
        // The API might be ready immediately, check after a short delay
        setTimeout(() => {
          if (window.YT && window.YT.Player && !youtubePlayer) {
            console.log('[Olivia Video] YouTube API available, loading player...');
            loadYouTubeAPI();
          }
        }, 100);
      };
      script.onerror = () => {
        console.error('[Olivia Video] Failed to load YouTube IFrame API script');
      };
      document.body.appendChild(script);
    } else {
      console.log('[Olivia Video] YouTube API already loaded, initializing player...');
      loadYouTubeAPI();
    }

    return () => {
      setYoutubePlayer((currentPlayer) => {
        if (currentPlayer) {
          try {
            currentPlayer.destroy();
          } catch (error) {
            console.warn('Error destroying player:', error);
          }
        }
        return null;
      });
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isYouTube, youtubeVideoId, autoPlayStarted]);

  useEffect(() => {
    if (!videoSrc) {
      console.log('No video source provided. Set NEXT_PUBLIC_VIDEO_URL in Vercel environment variables.');
      return;
    }

    // Start video immediately (no delay)
    if (isYouTube && youtubeVideoId) {
      // For YouTube, player will start when autoPlayStarted is true (already set in mount effect)
      // No action needed here as player initialization happens in separate effect
    } else if (!isYouTube && videoRef.current) {
      const video = videoRef.current;
      video.play()
        .then(() => {
          setIsPlaying(true);
          setShowPlayButton(false);
          setAutoPlayStarted(true);
        })
        .catch((error) => {
          console.log('Autoplay prevented, user interaction required:', error);
          setShowPlayButton(true);
        });
    }

    if (!isYouTube && videoRef.current) {
      const video = videoRef.current;
      
      // Debug: Log the video source
      console.log('Video source:', videoSrc);
      
      // Set the video source
      video.src = videoSrc;
      
      // Handle video loading errors
      const handleError = (e: Event) => {
        console.error('Video failed to load:', e);
        console.error('Video error details:', video.error);
        console.error('Video source was:', videoSrc);
        setVideoError(true);
      };
      const handleLoadedData = () => {
        console.log('Video loaded successfully');
        setVideoError(false);
      };

      video.addEventListener('error', handleError);
      video.addEventListener('loadeddata', handleLoadedData);

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
        video.removeEventListener('error', handleError);
        video.removeEventListener('loadeddata', handleLoadedData);
        video.removeEventListener('play', handlePlay);
        video.removeEventListener('pause', handlePause);
      };
    }
  }, [videoSrc, isYouTube, youtubeVideoId]);

  const handleVideoClick = () => {
    if (isYouTube) {
      // YouTube handles clicks internally, no custom handler needed
      return;
    }
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
    <div className="flex flex-col w-screen h-screen max-w-[1600px] mx-auto bg-background overflow-hidden">
      <header className="h-[4.5rem] flex-shrink-0 grid w-full items-center bg-background px-6 lg:px-20">
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

      <div className="flex-1 flex items-center justify-center overflow-hidden px-6 lg:px-20 pb-6">
        <div className="w-full h-full max-w-7xl relative flex items-center justify-center">
          <div 
            className={`relative w-full flex items-center justify-center ${!isMounted || (!isYouTube && videoSrc) ? 'cursor-pointer' : ''}`}
            onClick={handleVideoClick}
            style={{
              maxWidth: '100%',
              maxHeight: 'calc(100vh - 7rem)',
              width: '100%',
            }}
          >
            {videoSrc ? (
              isYouTube && youtubeVideoId ? (
                <div
                  ref={youtubePlayerRef}
                  className="rounded-3xl shadow-2xl overflow-hidden"
                  style={{
                    width: '100%',
                    height: 'auto',
                    maxWidth: '100%',
                    maxHeight: 'calc(100vh - 7rem)',
                    aspectRatio: '16/9',
                    minHeight: 0,
                    borderRadius: '24px',
                    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.5)',
                  }}
                  title="Olivia Pitch Video"
                />
              ) : (
                <video
                  ref={videoRef}
                  src={videoSrc}
                  controls
                  loop
                  muted
                  playsInline
                  preload="auto"
                  className="rounded-3xl shadow-2xl"
                  style={{
                    width: '100%',
                    height: 'auto',
                    maxWidth: '100%',
                    maxHeight: 'calc(100vh - 7rem)',
                    objectFit: 'contain',
                    aspectRatio: '16/9',
                    minHeight: 0,
                    borderRadius: '24px',
                    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.5)',
                  }}
                >
                  Your browser does not support the video tag.
                </video>
              )
            ) : (
              <div className="absolute inset-0 flex items-center justify-center bg-black/80 rounded-3xl" style={{ borderRadius: '24px' }}>
                <div className="text-center text-white p-6 max-w-md">
                  <p className="text-2xl mb-4 font-semibold">Pitch Video</p>
                  <p className="text-lg mb-2">Video will be available shortly</p>
                  <p className="text-sm text-gray-300">
                    Our pitch video is being finalized and will appear here soon. Please check back later.
                  </p>
                </div>
              </div>
            )}
            {videoError && !isYouTube && (
              <div className="absolute inset-0 flex items-center justify-center bg-black/80 rounded-3xl" style={{ borderRadius: '24px' }}>
                <div className="text-center text-white p-6 max-w-md">
                  <p className="text-2xl mb-4 font-semibold">Pitch Video</p>
                  <p className="text-lg mb-2">Video will be available shortly</p>
                  <p className="text-sm text-gray-300">
                    Our pitch video is being finalized and will appear here soon. Please check back later.
                  </p>
                </div>
              </div>
            )}
            {!isYouTube && showPlayButton && !isPlaying && !autoPlayStarted && (
              <div
                className="absolute inset-0 flex items-center justify-center bg-black/30 rounded-3xl pointer-events-none"
                style={{
                  borderRadius: '24px',
                  pointerEvents: 'none',
                }}
              >
                <div
                  className="w-20 h-20 flex items-center justify-center rounded-full bg-white/20 backdrop-blur-sm cursor-pointer hover:bg-white/30 transition-all pointer-events-auto"
                  style={{
                    border: '3px solid rgba(255, 255, 255, 0.5)',
                    marginBottom: '60px', // Position above video controls to avoid overlap
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
  );
}
