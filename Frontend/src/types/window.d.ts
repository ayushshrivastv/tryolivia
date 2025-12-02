// Extend the Window interface to include Solana wallets
/* eslint-disable @typescript-eslint/no-explicit-any */
interface Window {
  solana?: {
    isPhantom?: boolean;
    isConnected?: boolean;
    publicKey?: {
      toString(): string;
    };
    connect: (options?: { onlyIfTrusted?: boolean }) => Promise<{
      publicKey: {
        toString(): string;
      };
    }>;
    disconnect: () => Promise<void>;
    signTransaction: (transaction: any) => Promise<any>;
    signAllTransactions: (transactions: any[]) => Promise<any[]>;
    on: (event: string, callback: (args: unknown) => void) => void;
    removeListener: (event: string, callback: (args: unknown) => void) => void;
  };
  solflare?: {
    isConnected?: boolean;
    publicKey?: {
      toString(): string;
    };
    connect: (options?: { onlyIfTrusted?: boolean }) => Promise<{
      publicKey: {
        toString(): string;
      };
    }>;
    disconnect: () => Promise<void>;
    signTransaction: (transaction: any) => Promise<any>;
    signAllTransactions: (transactions: any[]) => Promise<any[]>;
    on: (event: string, callback: (args: unknown) => void) => void;
    removeListener: (event: string, callback: (args: unknown) => void) => void;
  };
  backpack?: {
    isConnected?: boolean;
    publicKey?: {
      toString(): string;
    };
    connect: (options?: { onlyIfTrusted?: boolean }) => Promise<{
      publicKey: {
        toString(): string;
      };
    }>;
    disconnect: () => Promise<void>;
    signTransaction: (transaction: any) => Promise<any>;
    signAllTransactions: (transactions: any[]) => Promise<any[]>;
    on: (event: string, callback: (args: unknown) => void) => void;
    removeListener: (event: string, callback: (args: unknown) => void) => void;
  };
  YT?: {
    Player: new (element: HTMLElement, config: YTPlayerConfig) => YTPlayer;
    PlayerState: {
      UNSTARTED: number;
      ENDED: number;
      PLAYING: number;
      PAUSED: number;
      BUFFERING: number;
      CUED: number;
    };
  };
  onYouTubeIframeAPIReady?: () => void;
}

interface YTPlayerConfig {
  videoId: string;
  playerVars?: {
    autoplay?: number;
    mute?: number;
    loop?: number;
    playlist?: string;
    controls?: number;
    modestbranding?: number;
    enablejsapi?: number;
  };
  events?: {
    onReady?: (event: YTOnReadyEvent) => void;
    onStateChange?: (event: YTOnStateChangeEvent) => void;
  };
}

interface YTPlayer {
  destroy: () => void;
  playVideo: () => void;
  pauseVideo: () => void;
  getAvailableQualityLevels: () => string[];
  setPlaybackQuality: (quality: string) => void;
}

interface YTOnReadyEvent {
  target: YTPlayer;
}

interface YTOnStateChangeEvent {
  data: number;
  target: YTPlayer;
}

