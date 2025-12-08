/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useState } from 'react';
import { MainLayout } from '@/src/layout/Layout';
import { useWallet } from '@solana/wallet-adapter-react';
import { WalletMultiButton } from '@solana/wallet-adapter-react-ui';
import { IconCheck, IconClock, IconTrophy, IconLoader2 } from '@tabler/icons-react';
import ClaimRewardModal from '@/src/components/ClaimRewardModal';

interface BetData {
  id: string;
  marketName: string;
  investedAmount: string;
  claimAmount: string;
}

export default function Portfolio() {
  const { connected, publicKey } = useWallet();
  const [showClaimModal, setShowClaimModal] = useState(false);
  const [selectedBet, setSelectedBet] = useState<BetData | null>(null);
  const [claimingId, setClaimingId] = useState<string | null>(null);
  const [claimStatus, setClaimStatus] = useState<'idle' | 'signing' | 'submitting' | 'success' | 'error'>('idle');
  const [claimMessage, setClaimMessage] = useState<string>('');

  // Mock bet data
  const completedBetData: BetData = {
    id: 'completed-bet',
    marketName: 'Will US government open up by Oct 31 2025 Halloween',
    investedAmount: '1.5',
    claimAmount: '2.5',
  };

  const handleClaimClick = (betId: string) => {
    if (!connected || !publicKey) {
      alert('Please connect your wallet');
      return;
    }

    // Open claim modal
    if (betId === 'completed-bet') {
      setSelectedBet(completedBetData);
      setShowClaimModal(true);
    }
  };

  const handleConfirmClaim = async () => {
    if (!selectedBet) return;

    setShowClaimModal(false);
    setClaimingId(selectedBet.id);
    setClaimStatus('signing');
    setClaimMessage('Requesting wallet signature...');

    try {
      // Simulate professional Solana transaction flow
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setClaimStatus('submitting');
      setClaimMessage('Submitting transaction to Solana...');

      // Simulate transaction submission
      await new Promise(resolve => setTimeout(resolve, 2000));

      setClaimStatus('success');
      setClaimMessage('Claim successful! Payout transferred to your wallet.');

      // Clear message after 5 seconds but keep "Claimed" state until page refresh
      setTimeout(() => {
        setClaimMessage('');
      }, 5000);
    } catch {
      setClaimStatus('error');
      setClaimMessage('Transaction failed. Please try again.');
      setTimeout(() => {
        setClaimingId(null);
        setClaimStatus('idle');
        setClaimMessage('');
      }, 3000);
    }
  };

  return (
    <MainLayout>
      <div className="relative w-full min-h-screen" style={{ backgroundColor: '#0a0a0a' }}>
        <div className="container mx-auto px-4 pt-24 pb-24 max-w-7xl">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-4xl md:text-5xl font-light mb-2 text-white" style={{ textShadow: '0 0 20px rgba(0,0,0,1), 0 0 40px rgba(0,0,0,1), 2px 2px 8px rgba(0,0,0,1)', WebkitTextStroke: '1px rgba(0,0,0,0.8)' }}>
              Portfolio
            </h1>
            <p className="text-white text-lg opacity-70" style={{ textShadow: '0 0 15px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)' }}>
              Manage your active positions and track your predictions
            </p>
          </div>

          {!connected ? (
            <div className="flex flex-col items-center justify-center py-20">
              <p className="text-white text-xl mb-6 text-center" style={{ textShadow: '0 0 15px rgba(0,0,0,1), 2px 2px 6px rgba(0,0,0,1)' }}>
                Please connect your wallet to view your bets and portfolio.
              </p>
              <WalletMultiButton className="!bg-[rgba(255,255,255,0.1)] hover:!bg-[rgba(255,255,255,0.2)] !rounded-full !px-6 !py-2 !border !border-[rgba(255,255,255,0.1)] !backdrop-blur-[10px]" />
            </div>
          ) : (
            <div className="space-y-6">
              {/* List of bets placed box */}
              <div
                className="rounded-lg p-6"
                style={{
                  backgroundColor: 'rgba(10, 10, 10, 0.7)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                }}
              >
                <h2 className="text-xl font-medium text-white mb-6" style={{ textShadow: '0 0 15px rgba(0,0,0,1), 2px 2px 6px rgba(0,0,0,1)' }}>
                  List of bets placed
                </h2>

                {/* Completed Bet Card - Horizontal Layout */}
                <div
                  className="rounded-lg p-5 mb-3 hover:border-opacity-30 transition-all duration-200"
                  style={{
                    backgroundColor: 'rgba(20, 20, 20, 0.6)',
                    border: '1px solid rgba(147, 51, 234, 0.3)',
                  }}
                >
                  <div className="flex items-center justify-between flex-wrap gap-4">
                    {/* Market Name & Details */}
                    <div className="flex-1 min-w-[300px]">
                      <div className="flex items-start gap-3 mb-2">
                        <h3 className="text-lg font-medium text-white" style={{ textShadow: '0 0 10px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)' }}>
                          Will US government open up by Oct 31 2025 Halloween
                        </h3>
                        <div className="flex items-center gap-2 px-2 py-1 rounded" style={{ backgroundColor: 'rgba(147, 51, 234, 0.15)' }}>
                          <IconTrophy className="h-4 w-4 text-purple-400" />
                          <span className="text-purple-400 text-xs font-medium">Completed</span>
                        </div>
                      </div>
                      <div className="flex items-center gap-4 text-sm text-white opacity-70 mb-3">
                        <div className="flex items-center gap-1">
                          <IconCheck className="h-4 w-4 text-green-400" />
                          <span className="text-green-400">Claimable</span>
                        </div>
                        <span className="text-xs opacity-60">You selected: <span className="font-medium" style={{ color: '#EF5350' }}>NO</span></span>
                      </div>
                      
                      {/* Voting Results */}
                      <div className="mt-3 space-y-2">
                        <div className="flex items-center gap-2">
                          <div className="flex-1 bg-gray-800 rounded-full h-2.5 overflow-hidden">
                            <div 
                              className="h-full rounded-full transition-all duration-500"
                              style={{ 
                                width: '86%',
                                background: '#EF5350'
                              }}
                            />
                          </div>
                          <span className="text-xs font-medium min-w-[60px]" style={{ color: '#EF5350' }}>86% NO</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <div className="flex-1 bg-gray-800 rounded-full h-2.5 overflow-hidden">
                            <div 
                              className="h-full rounded-full transition-all duration-500"
                              style={{ 
                                width: '8%',
                                background: '#4CAF50'
                              }}
                            />
                          </div>
                          <span className="text-xs font-medium min-w-[60px]" style={{ color: '#4CAF50' }}>8% YES</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <div className="flex-1 bg-gray-800 rounded-full h-2.5 overflow-hidden">
                            <div 
                              className="h-full rounded-full transition-all duration-500"
                              style={{ 
                                width: '6%',
                                background: '#9E9E9E'
                              }}
                            />
                          </div>
                          <span className="text-xs font-medium min-w-[60px]" style={{ color: '#9E9E9E' }}>6% Don&apos;t Know</span>
                        </div>
                      </div>
                    </div>

                    {/* Position & Status */}
                    <div className="flex items-center gap-6 flex-wrap">
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Your Position</p>
                        <p className="text-base font-medium" style={{ color: '#EF5350' }}>NO</p>
                      </div>
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Result</p>
                        <p className="text-green-400 text-base font-medium">Won</p>
                      </div>
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Payout</p>
                        <p className="text-white text-base font-medium">2.5 SOL</p>
                      </div>
                    </div>

                    {/* Claim Button */}
                    <div className="flex-shrink-0">
                      {claimingId === 'completed-bet' ? (
                        <button
                          disabled
                          className="rounded-full px-4 py-2 text-sm text-white transition-all duration-200 whitespace-nowrap flex items-center gap-2 opacity-75"
                          style={{
                            backgroundColor: 'rgba(10, 10, 10, 0.7)',
                            border: '1px solid rgba(255, 255, 255, 0.1)',
                            backdropFilter: 'blur(10px)',
                            cursor: 'not-allowed',
                          }}
                        >
                          {claimStatus === 'success' ? (
                            <>
                              <IconCheck className="h-4 w-4" />
                              Claimed
                            </>
                          ) : (
                            <>
                              <IconLoader2 className="h-4 w-4 animate-spin" />
                              {claimStatus === 'signing' ? 'Signing...' : 'Claiming...'}
                            </>
                          )}
                        </button>
                      ) : (
                        <button
                          onClick={() => handleClaimClick('completed-bet')}
                          className="rounded-full px-4 py-2 text-sm font-medium transition-all duration-200 whitespace-nowrap"
                          style={{
                            backgroundColor: '#ffffff',
                            color: '#000000',
                            border: '1px solid rgba(0, 0, 0, 0.1)',
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.backgroundColor = '#f5f5f5';
                            e.currentTarget.style.borderColor = 'rgba(0, 0, 0, 0.2)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.backgroundColor = '#ffffff';
                            e.currentTarget.style.borderColor = 'rgba(0, 0, 0, 0.1)';
                          }}
                        >
                          Claim
                        </button>
                      )}
                    </div>
                  </div>
                  {claimMessage && (
                    <div className={`mt-3 text-xs ${claimStatus === 'success' ? 'text-green-400' : claimStatus === 'error' ? 'text-red-400' : 'text-white opacity-70'}`}>
                      {claimMessage}
                    </div>
                  )}
                </div>

                {/* Active Bet Card - Horizontal Layout */}
                <div
                  className="rounded-lg p-5 mb-3 hover:border-opacity-30 transition-all duration-200"
                  style={{
                    backgroundColor: 'rgba(20, 20, 20, 0.6)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                  }}
                >
                  <div className="flex items-center justify-between flex-wrap gap-4">
                    {/* Market Name & Details */}
                    <div className="flex-1 min-w-[300px]">
                      <div className="flex items-start gap-3 mb-2">
                        <h3 className="text-lg font-medium text-white" style={{ textShadow: '0 0 10px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)' }}>
                          NY Mayor Election
                        </h3>
                        <div className="flex items-center gap-2 px-2 py-1 rounded" style={{ backgroundColor: 'rgba(34, 197, 94, 0.15)' }}>
                          <IconCheck className="h-4 w-4 text-green-400" />
                          <span className="text-green-400 text-xs font-medium">Active</span>
                        </div>
                      </div>
                      <div className="flex items-center gap-4 text-sm text-white opacity-70">
                        <div className="flex items-center gap-1">
                          <IconClock className="h-4 w-4" />
                          <span>Ends on 4th Nov</span>
                        </div>
                        <span className="text-xs opacity-60">Bet placed by user</span>
                      </div>
                    </div>

                    {/* Position & Status */}
                    <div className="flex items-center gap-6 flex-wrap">
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Position</p>
                        <p className="text-base font-medium" style={{ color: '#4CAF50' }}>YES</p>
                      </div>
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Status</p>
                        <p className="text-white text-base font-medium opacity-80">Pending</p>
                      </div>
                      <div className="text-center">
                        <p className="text-white text-xs opacity-60 mb-1">Shares</p>
                        <p className="text-white text-base font-medium">--</p>
                      </div>
                    </div>

                    {/* Claim Button */}
                    <div className="flex-shrink-0">
                      <button
                        className="rounded-full px-4 py-2 text-sm text-white transition-all duration-200 whitespace-nowrap opacity-50 cursor-not-allowed"
                        style={{
                          backgroundColor: 'rgba(10, 10, 10, 0.7)',
                          border: '1px solid rgba(255, 255, 255, 0.1)',
                          backdropFilter: 'blur(10px)',
                        }}
                      >
                        Claim if Wins
                      </button>
                    </div>
                  </div>
                </div>

                {/* Empty State (if no bets) - commented out for now since we have one bet */}
                {/* <div className="text-center py-12">
                  <p className="text-white text-lg opacity-60">No active bets</p>
                </div> */}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Claim Reward Modal */}
      {selectedBet && (
        <ClaimRewardModal
          isOpen={showClaimModal}
          onClose={() => {
            setShowClaimModal(false);
            setSelectedBet(null);
          }}
          onConfirm={handleConfirmClaim}
          marketName={selectedBet.marketName}
          investedAmount={selectedBet.investedAmount}
          claimAmount={selectedBet.claimAmount}
          isLoading={claimingId === selectedBet.id && (claimStatus === 'signing' || claimStatus === 'submitting')}
        />
      )}
    </MainLayout>
  );
}

