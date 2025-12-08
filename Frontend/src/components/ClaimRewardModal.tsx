/**
 * Olivia: Decentralised Permissionless Prediction Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { X, Trophy } from 'lucide-react';
import { IconLoader2, IconCheck } from '@tabler/icons-react';

interface ClaimRewardModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  marketName: string;
  investedAmount: string;
  claimAmount: string;
  isLoading?: boolean;
}

export default function ClaimRewardModal({
  isOpen,
  onClose,
  onConfirm,
  marketName,
  investedAmount,
  claimAmount,
  isLoading = false,
}: ClaimRewardModalProps) {
  if (!isOpen) return null;

  // Stripe-style number formatting - removes trailing zeros and unnecessary decimals
  const formatNumber = (num: number): string => {
    // Handle whole numbers - return without decimals
    if (Number.isInteger(num)) {
      return num.toString();
    }
    // For decimal numbers, remove trailing zeros but keep at least one decimal place if needed
    return num.toFixed(4).replace(/\.?0+$/, '');
  };

  const formatCurrency = (amount: string): string => {
    const num = parseFloat(amount);
    return formatNumber(num);
  };

  const profit = parseFloat(claimAmount) - parseFloat(investedAmount);
  const profitPercentage = ((profit / parseFloat(investedAmount)) * 100).toFixed(1);

  return (
    <div
      className="fixed inset-0 flex items-center justify-center p-4"
      style={{ backgroundColor: 'rgba(0, 0, 0, 0.7)', zIndex: 9999 }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl rounded-xl p-6 max-h-[90vh] overflow-y-auto"
        style={{
          backgroundColor: 'rgba(255, 255, 255, 0.95)',
          border: '1px solid rgba(0, 0, 0, 0.1)',
          backdropFilter: 'blur(10px)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div
              className="p-2 rounded-full"
              style={{ backgroundColor: 'rgba(34, 197, 94, 0.1)' }}
            >
              <Trophy className="h-6 w-6" style={{ color: '#22c55e' }} />
            </div>
            <h2 className="text-2xl font-semibold" style={{ color: '#000000' }}>
              Claim Reward
            </h2>
          </div>
          <button
            onClick={onClose}
            className="hover:opacity-70 transition-opacity"
            style={{ color: '#000000' }}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Market Info */}
        <div className="mb-6">
          <h3 className="text-lg font-medium mb-2" style={{ color: '#000000' }}>
            Market
          </h3>
          <p className="text-base" style={{ color: '#4b5563' }}>
            {marketName}
          </p>
        </div>

        {/* Reward Details Box */}
        <div
          className="rounded-lg p-6 mb-6"
          style={{
            backgroundColor: '#f9fafb',
            border: '1px solid rgba(0, 0, 0, 0.1)',
          }}
        >
          <h3 className="text-sm font-medium mb-4 uppercase tracking-wider" style={{ color: '#6b7280' }}>
            Reward Details
          </h3>

          <div className="space-y-4">
            {/* Invested Amount */}
            <div className="flex items-center justify-between pb-3 border-b border-gray-200">
              <div>
                <p className="text-sm font-medium mb-1" style={{ color: '#6b7280' }}>
                  Invested Amount
                </p>
              </div>
              <div className="text-right">
                <p className="text-lg font-semibold" style={{ color: '#000000' }}>
                  {formatCurrency(investedAmount)} SOL
                </p>
              </div>
            </div>

            {/* Claim Amount */}
            <div className="flex items-center justify-between pb-3 border-b border-gray-200">
              <div>
                <p className="text-sm font-medium mb-1" style={{ color: '#6b7280' }}>
                  Reward Amount
                </p>
              </div>
              <div className="text-right">
                <p className="text-lg font-semibold" style={{ color: '#22c55e' }}>
                  {formatCurrency(claimAmount)} SOL
                </p>
              </div>
            </div>

            {/* Profit */}
            <div className="flex items-center justify-between pt-2">
              <div>
                <p className="text-sm font-medium mb-1" style={{ color: '#6b7280' }}>
                  Profit
                </p>
                <p className="text-xs" style={{ color: '#9ca3af' }}>
                  {profitPercentage}% return
                </p>
              </div>
              <div className="text-right">
                <p className="text-lg font-semibold" style={{ color: '#22c55e' }}>
                  +{formatNumber(profit)} SOL
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Summary */}
        <div
          className="rounded-lg p-4 mb-6"
          style={{
            backgroundColor: '#000000',
            border: '1px solid rgba(255, 255, 255, 0.1)',
          }}
        >
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium" style={{ color: '#ffffff' }}>
              Total to Receive
            </p>
            <p className="text-xl font-bold" style={{ color: '#ffffff' }}>
              {formatCurrency(claimAmount)} SOL
            </p>
          </div>
        </div>

        {/* Info Notice */}
        <div
          className="rounded-lg p-4 mb-6"
          style={{
            backgroundColor: '#f3f4f6',
            border: '1px solid rgba(0, 0, 0, 0.1)',
          }}
        >
          <p className="text-xs leading-relaxed" style={{ color: '#6b7280' }}>
            By confirming, you will receive {formatCurrency(claimAmount)} SOL in your wallet. 
            This transaction will be processed on the Solana blockchain.
          </p>
        </div>

        {/* Form Actions */}
        <div className="flex items-center justify-end gap-3 pt-4">
          <button
            type="button"
            onClick={onClose}
            disabled={isLoading}
            className="px-6 py-2.5 rounded-full text-sm font-medium transition-all duration-200 disabled:opacity-50"
            style={{
              backgroundColor: 'transparent',
              border: '1px solid rgba(0, 0, 0, 0.2)',
              color: '#000000',
            }}
            onMouseEnter={(e) => {
              if (!isLoading) {
                e.currentTarget.style.backgroundColor = '#f3f4f6';
              }
            }}
            onMouseLeave={(e) => {
              if (!isLoading) {
                e.currentTarget.style.backgroundColor = 'transparent';
              }
            }}
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={isLoading}
            className="px-6 py-2.5 rounded-full text-sm font-medium transition-all duration-200 flex items-center gap-2 disabled:opacity-50"
            style={{
              backgroundColor: '#000000',
              border: '1px solid #000000',
              color: '#ffffff',
            }}
            onMouseEnter={(e) => {
              if (!isLoading) {
                e.currentTarget.style.backgroundColor = '#1f2937';
                e.currentTarget.style.borderColor = '#1f2937';
              }
            }}
            onMouseLeave={(e) => {
              if (!isLoading) {
                e.currentTarget.style.backgroundColor = '#000000';
                e.currentTarget.style.borderColor = '#000000';
              }
            }}
          >
            {isLoading ? (
              <>
                <IconLoader2 className="h-4 w-4 animate-spin" />
                Processing...
              </>
            ) : (
              <>
                <IconCheck className="h-4 w-4" />
                Accept Reward
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

