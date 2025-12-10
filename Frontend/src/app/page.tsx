/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useEffect, useState } from 'react';
import FeatureSections from '../home/FeatureSections';
import { MainLayout } from '../layout/Layout';
import HeroSection from '../home/HeroSection';
import Dither from '../components/Dither';
import HomeBanner from '../home/HomeBanner';
import EarlySignupModal from '../components/EarlySignupModal';

export default function Home() {
  const [showEarlySignup, setShowEarlySignup] = useState(false);
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    setIsMounted(true);
    // Check if user has already accessed
    if (typeof window !== 'undefined') {
      const hasEarlyAccess = localStorage.getItem('olivia_early_access');
      console.log('🔍 Early access check:', hasEarlyAccess);
      console.log('🔍 isMounted:', true);
      if (!hasEarlyAccess) {
        console.log('✅ Showing early signup modal');
        // Use setTimeout to ensure state update happens after mount
        setTimeout(() => {
          setShowEarlySignup(true);
        }, 100);
      } else {
        console.log('❌ User already has early access, skipping modal');
        console.log('💡 To test: Run localStorage.removeItem("olivia_early_access") in console and refresh');
      }
    }
  }, []);

  useEffect(() => {
    console.log('🔍 Home component state:', { showEarlySignup, isMounted });
  }, [showEarlySignup, isMounted]);

  const handleCloseModal = () => {
    // Store in localStorage that user has accessed (whether via form or close button)
    if (typeof window !== 'undefined') {
      localStorage.setItem('olivia_early_access', 'true');
    }
    setShowEarlySignup(false);
  };

  return (
    <MainLayout>
      {/* Fixed dark background to prevent white flash on refresh */}
      <div className="fixed inset-0 bg-[#0a0a0a]" style={{ zIndex: 0 }} />
      
      {/* Dither background - only on landing page */}
      <div className="fixed inset-0" style={{ zIndex: 1 }}>
        <Dither
          waveColor={[0.3, 0.3, 0.3]}
          disableAnimation={false}
          enableMouseInteraction={true}
          mouseRadius={0.3}
          colorNum={4}
          waveAmplitude={0.3}
          waveFrequency={3}
          waveSpeed={0.05}
        />
      </div>
      <div 
        className="relative w-full min-h-screen transition-opacity duration-300"
        style={{ 
          zIndex: 10,
          opacity: showEarlySignup ? 0.3 : 1,
          pointerEvents: showEarlySignup ? 'none' : 'auto',
        }}
      >
        <HeroSection />
        <FeatureSections />
        <HomeBanner />
      </div>
      
      {/* Early Signup Modal - rendered outside MainLayout to avoid z-index issues */}
      {isMounted && showEarlySignup && (
        <EarlySignupModal 
          isOpen={showEarlySignup} 
          onClose={handleCloseModal}
        />
      )}
    </MainLayout>
  );
}
