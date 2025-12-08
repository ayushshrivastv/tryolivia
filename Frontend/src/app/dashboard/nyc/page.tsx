/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useState, useEffect } from 'react';
import { MainLayout } from '@/src/layout/Layout';
import Image from 'next/image';
import ChartArea from '@/src/trade/Chart/ChartArea';

export default function NYCDashboard() {
  const [timeRemaining, setTimeRemaining] = useState({
    days: 0,
    hours: 0,
    minutes: 0,
    seconds: 0,
  });

  // Countdown timer to November 4th
  useEffect(() => {
    const calculateTimeRemaining = () => {
      const now = new Date();
      // Set election date to November 4th, 2025 at 7:00 PM (19:00) in local timezone
      // This ensures the countdown shows the exact time remaining
      const electionDate = new Date(2025, 10, 4, 19, 0, 0); // Month is 0-indexed, so 10 = November, 19:00 = 7 PM
      const difference = electionDate.getTime() - now.getTime();

      if (difference > 0) {
        const days = Math.floor(difference / (1000 * 60 * 60 * 24));
        const hours = Math.floor((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((difference % (1000 * 60)) / 1000);

        setTimeRemaining({ days, hours, minutes, seconds });
      } else {
        // If election has passed, show zeros
        setTimeRemaining({ days: 0, hours: 0, minutes: 0, seconds: 0 });
      }
    };

    calculateTimeRemaining();
    const interval = setInterval(calculateTimeRemaining, 1000);

    return () => clearInterval(interval);
  }, []);

  return (
    <MainLayout>
      <div className="relative w-full min-h-screen" style={{ backgroundColor: '#0a0a0a' }}>
        <div className="container mx-auto px-4 pt-24 pb-12 max-w-7xl">
          {/* Header */}
          <div className="text-center mb-8">
            <h1 className="text-4xl md:text-5xl font-light mb-2 text-white" style={{ textShadow: '0 0 20px rgba(0,0,0,1), 0 0 40px rgba(0,0,0,1), 2px 2px 8px rgba(0,0,0,1)', WebkitTextStroke: '1px rgba(0,0,0,0.8)' }}>
              Olivia Private Prediction Market
            </h1>
            <h2 className="text-2xl md:text-3xl font-light mb-4 text-white opacity-80" style={{ textShadow: '0 0 15px rgba(0,0,0,1), 1px 1px 4px rgba(0,0,0,1)' }}>
              NYC Mayoral Election Live Forecast
            </h2>
          </div>

          {/* Countdown Timer */}
          <div className="flex justify-center mb-8">
            <div className="text-center">
              <p className="text-white text-lg mb-3" style={{ textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                Election in 4th Nov
              </p>
              <div className="flex items-center gap-4 text-white font-medium" style={{ textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                <div className="text-center">
                  <div className="text-3xl font-bold">{String(timeRemaining.days).padStart(2, '0')}</div>
                  <div className="text-xs opacity-70">day</div>
                </div>
                <div className="text-2xl opacity-50">:</div>
                <div className="text-center">
                  <div className="text-3xl font-bold">{String(timeRemaining.hours).padStart(2, '0')}</div>
                  <div className="text-xs opacity-70">hrs</div>
                </div>
                <div className="text-2xl opacity-50">:</div>
                <div className="text-center">
                  <div className="text-3xl font-bold">{String(timeRemaining.minutes).padStart(2, '0')}</div>
                  <div className="text-xs opacity-70">mins</div>
                </div>
                <div className="text-2xl opacity-50">:</div>
                <div className="text-center">
                  <div className="text-3xl font-bold">{String(timeRemaining.seconds).padStart(2, '0')}</div>
                  <div className="text-xs opacity-70" style={{ visibility: 'hidden' }}>sec</div>
                </div>
              </div>
            </div>
          </div>

          {/* Candidates with Images */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12 max-w-4xl mx-auto">
            {/* Zohran Mamdani */}
            <div
              className="overflow-hidden"
              style={{
                backgroundColor: 'rgba(10, 10, 10, 0.7)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                backdropFilter: 'blur(10px)',
                borderRadius: '24px',
              }}
            >
              <div className="relative w-full h-64 overflow-hidden" style={{ borderRadius: '24px 24px 0 0' }}>
                <Image
                  src="/Zohran.png"
                  alt="Zohran Mamdani"
                  fill
                  className="object-cover"
                  style={{ borderRadius: '24px 24px 0 0' }}
                />
              </div>
              <div className="p-6">
                <h3 className="text-xl font-semibold text-white mb-2" style={{ textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                  Zohran Mamdani
                </h3>
                <div className="text-3xl font-bold" style={{ color: '#4CAF50', textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                  88.8%
                </div>
              </div>
            </div>

            {/* Andrew Cuomo */}
            <div
              className="overflow-hidden"
              style={{
                backgroundColor: 'rgba(10, 10, 10, 0.7)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                backdropFilter: 'blur(10px)',
                borderRadius: '24px',
              }}
            >
              <div className="relative w-full h-64 overflow-hidden" style={{ borderRadius: '24px 24px 0 0' }}>
                <Image
                  src="/cuomo.png"
                  alt="Andrew Cuomo"
                  fill
                  className="object-cover"
                  style={{ borderRadius: '24px 24px 0 0' }}
                />
              </div>
              <div className="p-6">
                <h3 className="text-xl font-semibold text-white mb-2" style={{ textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                  Andrew Cuomo
                </h3>
                <div className="text-3xl font-bold" style={{ color: '#4CAF50', textShadow: '0 0 10px rgba(0,0,0,1)' }}>
                  11.1%
                </div>
              </div>
            </div>
          </div>

          {/* Other Candidates */}
          <div className="mb-8 max-w-4xl mx-auto">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="text-center">
                <p className="text-white text-sm opacity-70 mb-1">Zohran Mamdani</p>
                <p className="text-white text-lg font-semibold" style={{ color: '#4CAF50' }}>88.8%</p>
              </div>
              <div className="text-center">
                <p className="text-white text-sm opacity-70 mb-1">Andrew Cuomo</p>
                <p className="text-white text-lg font-semibold" style={{ color: '#4CAF50' }}>11.1%</p>
              </div>
              <div className="text-center">
                <p className="text-white text-sm opacity-70 mb-1">Curtis Sliwa</p>
                <p className="text-white text-lg font-semibold" style={{ color: '#9E9E9E' }}>&lt;1%</p>
              </div>
              <div className="text-center">
                <p className="text-white text-sm opacity-70 mb-1">Eric Adams</p>
                <p className="text-white text-lg font-semibold" style={{ color: '#9E9E9E' }}>&lt;1%</p>
              </div>
            </div>
          </div>

          {/* Chart Section */}
          <div className="mt-12 max-w-7xl mx-auto" style={{ height: '500px' }}>
            <ChartArea market="NYC-MAYOR" />
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

