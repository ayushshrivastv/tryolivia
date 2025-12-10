/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import Image from 'next/image';
import { IconRocket } from '@tabler/icons-react';

interface EarlySignupModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function EarlySignupModal({ isOpen, onClose }: EarlySignupModalProps) {
  const [email, setEmail] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showSuccessMessage, setShowSuccessMessage] = useState(false);
  const [mounted, setMounted] = useState(false);

  // Ensure we're on the client side
  useEffect(() => {
    setMounted(true);
    console.log('EarlySignupModal mounted, isOpen:', isOpen);
  }, [isOpen]);

  // Reset form state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setEmail('');
      setIsSubmitting(false);
      setShowSuccessMessage(false);
    }
  }, [isOpen]);

  // Prevent body scroll when modal is open and prevent keyboard shortcuts
  useEffect(() => {
    if (isOpen && mounted) {
      document.body.style.overflow = 'hidden';
      
      // Prevent Escape key from closing the modal
      const handleKeyDown = (e: KeyboardEvent) => {
        // Prevent Escape key from closing the modal
        if (e.key === 'Escape') {
          e.preventDefault();
          e.stopPropagation();
        }
      };
      
      window.addEventListener('keydown', handleKeyDown, true);
      
      return () => {
        document.body.style.overflow = 'unset';
        window.removeEventListener('keydown', handleKeyDown, true);
      };
    } else if (mounted) {
      document.body.style.overflow = 'unset';
    }
  }, [isOpen, mounted]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    // Simulate submission
    setTimeout(() => {
      setIsSubmitting(false);
      setShowSuccessMessage(true);
      
      // Store in localStorage that user has accessed
      if (typeof window !== 'undefined') {
        localStorage.setItem('olivia_early_access', 'true');
      }
    }, 500);
  };

  // Debug logging
  useEffect(() => {
    console.log('🔍 EarlySignupModal state:', { isOpen, mounted, hasWindow: typeof window !== 'undefined', hasBody: typeof window !== 'undefined' && !!document.body });
  }, [isOpen, mounted]);

  // Don't render if conditions aren't met
  if (!isOpen || !mounted) {
    console.log('❌ EarlySignupModal returning null:', { isOpen, mounted });
    return null;
  }

  if (typeof window === 'undefined' || !document.body) {
    console.log('❌ EarlySignupModal: window or body not available');
    return null;
  }

  console.log('✅ EarlySignupModal rendering modal content via portal');

  const modalContent = (
    <div 
      className="fixed inset-0 z-[99999] flex items-center justify-center"
      style={{
        backgroundColor: 'rgba(0, 0, 0, 0.7)',
        backdropFilter: 'blur(10px)',
      }}
    >
      {/* Background blur effect */}
      <div className="absolute inset-0 bg-[#0a0a0a] opacity-90" />
      
      {/* Modal Content */}
      <div className="relative z-10 w-full max-w-md mx-4 max-h-[90vh] overflow-y-auto">
        <div 
          className={`rounded-xl ${showSuccessMessage ? 'p-6 md:p-8' : 'p-8 md:p-10'} transition-all duration-200`}
          style={{
            backgroundColor: 'rgba(10, 10, 10, 0.9)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(20px)',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
          }}
        >

          {/* Logo/Icon - Only show on early access form */}
          {!showSuccessMessage && (
            <div className="flex justify-center mb-4">
              <div className="relative w-32 h-32 md:w-40 md:h-40">
                <Image
                  src="/OliviaBird.png"
                  alt="Olivia"
                  width={160}
                  height={160}
                  className="w-full h-full object-contain"
                  style={{
                    filter: 'drop-shadow(0 0 20px rgba(255, 255, 255, 0.2))',
                  }}
                />
              </div>
            </div>
          )}

          {showSuccessMessage ? (
            <div className="text-center">
              <div className="mb-4 flex justify-center">
                <div className="relative w-24 h-24 md:w-32 md:h-32">
                  <Image
                    src="/OliviaBird.png"
                    alt="Olivia"
                    width={128}
                    height={128}
                    className="w-full h-full object-contain"
                    style={{
                      filter: 'drop-shadow(0 0 20px rgba(255, 255, 255, 0.2))',
                    }}
                  />
                </div>
              </div>
              
              <h2 
                className="text-2xl md:text-3xl text-center mb-4 text-white"
                style={{ 
                  textShadow: '0 0 20px rgba(0,0,0,1), 0 0 40px rgba(0,0,0,1), 2px 2px 8px rgba(0,0,0,1)',
                  WebkitTextStroke: '1px rgba(0,0,0,0.8)',
                  fontFamily: 'PP Editorial New, serif',
                  fontWeight: 200,
                }}
              >
                Welcome to Olivia
              </h2>
              
              <div 
                className="mb-4 p-4 rounded-xl"
                style={{
                  backgroundColor: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                }}
              >
                <p 
                  className="text-white/90 text-center mb-2 text-xs"
                  style={{ 
                    textShadow: '0 0 10px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)',
                    fontFamily: 'GT America Mono, monospace',
                  }}
                >
                  You have successfully entered
                </p>
                
                <p 
                  className="text-white text-center mb-2 text-lg md:text-xl"
                  style={{ 
                    textShadow: '0 0 15px rgba(0,0,0,1), 1px 1px 5px rgba(0,0,0,1)',
                    fontFamily: 'GT America Mono, monospace',
                    fontWeight: 300,
                  }}
                >
                  Demo Version 1.0
                </p>
                
                <p 
                  className="text-white/70 text-center text-xs leading-relaxed"
                  style={{ 
                    textShadow: '0 0 10px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)',
                    fontFamily: 'GT America Mono, monospace',
                  }}
                >
                  This is a demonstration version of the original <span className="font-medium text-white/80">Onbuilt Product - Version 1</span>
                </p>
              </div>
              
              <p 
                className="text-white/60 text-center text-xs mb-4"
                style={{ 
                  textShadow: '0 0 8px rgba(0,0,0,1), 1px 1px 3px rgba(0,0,0,1)',
                  fontFamily: 'GT America Mono, monospace',
                }}
              >
                Explore our prediction market platform and experience the future of decentralized trading.
              </p>

              <button
                onClick={onClose}
                className="w-full px-6 py-3 rounded-full text-white text-sm transition-all duration-200 flex items-center justify-center gap-2"
                style={{
                  backgroundColor: 'rgba(10, 10, 10, 0.7)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                  fontFamily: 'GT America Mono, monospace',
                  fontWeight: 300,
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                  e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
                  e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
                }}
              >
                <IconRocket className="h-4 w-4" />
                Continue to Platform
              </button>
            </div>
          ) : (
            <>
              {/* Heading */}
              <h2 
                className="text-3xl md:text-4xl text-center mb-3 text-white"
                style={{ 
                  textShadow: '0 0 20px rgba(0,0,0,1), 0 0 40px rgba(0,0,0,1), 2px 2px 8px rgba(0,0,0,1)',
                  WebkitTextStroke: '1px rgba(0,0,0,0.8)',
                  fontFamily: 'PP Editorial New, serif',
                  fontWeight: 200,
                }}
              >
                Get Early Access
              </h2>
              
              <p 
                className="text-gray-300 text-center mb-8 text-sm md:text-base"
                style={{ 
                  textShadow: '0 0 15px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)',
                  fontFamily: 'GT America Mono, monospace',
                  fontWeight: 300,
                }}
              >
                Be among the first to experience the future of prediction markets. Join our waitlist for exclusive early access.
              </p>

              {/* Form */}
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Enter your email"
                    required
                    disabled={isSubmitting}
                    className="w-full px-4 py-3 rounded-xl text-white placeholder-white/50 text-sm transition-all duration-200 disabled:opacity-50"
                    style={{
                      backgroundColor: 'rgba(10, 10, 10, 0.7)',
                      border: '1px solid rgba(255, 255, 255, 0.1)',
                      backdropFilter: 'blur(10px)',
                      fontFamily: 'GT America Mono, monospace',
                    }}
                    onFocus={(e) => {
                      e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.9)';
                      e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
                    }}
                    onBlur={(e) => {
                      e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
                      e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
                    }}
                  />
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full px-6 py-3 rounded-full text-white text-sm transition-all duration-200 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{
                    backgroundColor: 'rgba(10, 10, 10, 0.7)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                    fontFamily: 'GT America Mono, monospace',
                    fontWeight: 300,
                  }}
                  onMouseEnter={(e) => {
                    if (!isSubmitting) {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                      e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.2)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (!isSubmitting) {
                      e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
                      e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
                    }
                  }}
                >
                  {isSubmitting ? (
                    'Submitting...'
                  ) : (
                    <>
                      <IconRocket className="h-4 w-4" />
                      Get Early Access
                    </>
                  )}
                </button>
              </form>

              {/* Footer text */}
              <p className="text-gray-500 text-xs text-center mt-6" style={{ fontFamily: 'GT America Mono, monospace', fontWeight: 300 }}>
                By continuing, you agree to receive updates about Olivia
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  );

  // Use portal to render at document body level
  try {
    return createPortal(modalContent, document.body);
  } catch (error) {
    console.error('❌ Error creating portal:', error);
    return null;
  }
}

