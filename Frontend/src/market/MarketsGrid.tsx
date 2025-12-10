/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useState, useEffect } from 'react';
import { CometCard } from '@/src/ui/CometCard';
import { Input } from '@/src/ui/Input';
import { Button } from '@/src/ui/Button';
import { X } from 'lucide-react';

interface MarketItem {
  id: string;
  title: string;
  question: string;
  probability: string;
  category: string;
  iconColor: string;
  pair: string;
  image: string;
}

const mockMarkets: MarketItem[] = [
  {
    id: '1',
    title: 'NYC Mayoral Election',
    question: 'Zohran Mamdani',
    probability: '88.5%',
    category: 'Politics',
    iconColor: '#5522e0',
    pair: 'NYC-MAYOR',
    image: '/NY Election.png'
  },
  {
    id: '2',
    title: 'Government Shutdown',
    question: 'November 23rd or Before',
    probability: '65%',
    category: 'Politics',
    iconColor: '#F7931A',
    pair: 'GOV-SHUTDOWN',
    image: '/Government Shutdown.jpeg'
  },
  {
    id: '3',
    title: 'Mamdani Victory Margin',
    question: '10-20%',
    probability: '47%',
    category: 'Politics',
    iconColor: '#E6007A',
    pair: 'MAMDANI-MARGIN',
    image: '/Zohran_Mamdani.jpg'
  },
  {
    id: '4',
    title: 'Presidential Election 2028',
    question: 'JD Vance',
    probability: '28%',
    category: 'Politics',
    iconColor: '#0033AD',
    pair: 'PRES-2028',
    image: '/Election 2028.jpeg'
  },
  {
    id: '5',
    title: 'Solana Price October',
    question: 'What price will Solana hit?',
    probability: '45%',
    category: 'Crypto',
    iconColor: '#9945FF',
    pair: 'SOL-PRICE',
    image: '/Solana.jpg'
  },
  {
    id: '6',
    title: 'Polymarket US Launch',
    question: 'Will it go live in 2025?',
    probability: '90%',
    category: 'Crypto',
    iconColor: '#26A17B',
    pair: 'POLY-US',
    image: '/PolyMarket.png'
  }
];

interface MarketsGridProps {
  onFormToggle?: (isOpen: boolean) => void;
}

export default function MarketsGrid({ onFormToggle }: MarketsGridProps = {}) {
  const [markets, setMarkets] = useState<MarketItem[]>(mockMarkets);
  const [searchQuery, setSearchQuery] = useState('');
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [showComingSoon, setShowComingSoon] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    question: '',
    category: '',
    startDate: '',
    endDate: '',
    imageUrl: '',
  });

  useEffect(() => {
    if (searchQuery) {
      const filtered = mockMarkets.filter(market =>
        market.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        market.question.toLowerCase().includes(searchQuery.toLowerCase())
      );
      setMarkets(filtered);
    } else {
      setMarkets(mockMarkets);
    }
  }, [searchQuery]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setShowCreateForm(false);
    onFormToggle?.(false);
    setShowComingSoon(true);
    // Reset form
    setFormData({
      name: '',
      question: '',
      category: '',
      startDate: '',
      endDate: '',
      imageUrl: '',
    });
    // Hide message after 3 seconds
    setTimeout(() => setShowComingSoon(false), 3000);
  };

  const handleClose = () => {
    setShowCreateForm(false);
    onFormToggle?.(false);
    setFormData({
      name: '',
      question: '',
      category: '',
      startDate: '',
      endDate: '',
      imageUrl: '',
    });
  };

  const handleOpenForm = () => {
    setShowCreateForm(true);
    onFormToggle?.(true);
  };

  return (
    <div>
      {/* Search Bar and Create Market Button */}
      <div className="mb-8 flex items-center gap-4">
        <div className="relative max-w-md flex-1">
          <input
            type="text"
            placeholder="Search markets..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-4 py-3 rounded-xl text-white text-sm transition-all duration-200"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.7)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
              fontFamily: 'GT America Mono, monospace',
            }}
          />
        </div>
        <button
          onClick={handleOpenForm}
          className="rounded-full px-4 py-2 text-sm transition-all duration-200 cursor-pointer hover:opacity-80 whitespace-nowrap"
          style={{
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
            color: 'white',
          }}
        >
          Create Market
        </button>
      </div>

      {/* Coming Soon Message */}
      {showComingSoon && (
        <div
          className="fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 px-6 py-4 rounded-xl transition-all duration-300"
          style={{
            backgroundColor: 'rgba(10, 10, 10, 0.95)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
            color: 'white',
            zIndex: 10000,
          }}
        >
          <p className="text-lg font-medium">Features coming soon</p>
        </div>
      )}

      {/* Create Market Form Modal */}
      {showCreateForm && (
        <div
          className="fixed inset-0 flex items-center justify-center p-4"
          style={{ backgroundColor: 'rgba(0, 0, 0, 0.7)', zIndex: 9999 }}
          onClick={handleClose}
        >
          <div
            className="w-full max-w-2xl rounded-xl p-6 max-h-[90vh] overflow-y-auto"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.95)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-semibold text-white">Create New Market</h2>
              <button
                onClick={handleClose}
                className="text-white hover:opacity-70 transition-opacity"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Market Name */}
              <div>
                <label className="block text-sm font-medium text-white mb-2">
                  Market Name *
                </label>
                <Input
                  type="text"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  placeholder="e.g., NYC Mayoral Election"
                  required
                  className="bg-card border-border text-white"
                />
              </div>

              {/* Market Question/Description */}
              <div>
                <label className="block text-sm font-medium text-white mb-2">
                  Market Question *
                </label>
                <Input
                  type="text"
                  name="question"
                  value={formData.question}
                  onChange={handleInputChange}
                  placeholder="e.g., Who will win the election?"
                  required
                  className="bg-card border-border text-white"
                />
              </div>

              {/* Category */}
              <div>
                <label className="block text-sm font-medium text-white mb-2">
                  Category *
                </label>
                <select
                  name="category"
                  value={formData.category}
                  onChange={handleInputChange}
                  required
                  className="w-full px-3 py-2 rounded-md text-white text-sm bg-card border border-border focus:ring-2 focus:ring-ring focus:ring-offset-0 outline-none"
                  style={{
                    backgroundColor: 'rgba(10, 10, 10, 0.7)',
                    borderColor: 'rgba(255, 255, 255, 0.1)',
                  }}
                >
                  <option value="">Select a category</option>
                  <option value="Politics">Politics</option>
                  <option value="Sports">Sports</option>
                  <option value="Technology">Technology</option>
                  <option value="Economics">Economics</option>
                  <option value="Entertainment">Entertainment</option>
                  <option value="Other">Other</option>
                </select>
              </div>

              {/* Dates */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-white mb-2">
                    Start Date *
                  </label>
                  <Input
                    type="date"
                    name="startDate"
                    value={formData.startDate}
                    onChange={handleInputChange}
                    required
                    className="bg-card border-border text-white"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-white mb-2">
                    End Date *
                  </label>
                  <Input
                    type="date"
                    name="endDate"
                    value={formData.endDate}
                    onChange={handleInputChange}
                    required
                    className="bg-card border-border text-white"
                  />
                </div>
              </div>

              {/* Image URL */}
              <div>
                <label className="block text-sm font-medium text-white mb-2">
                  Market Image URL
                </label>
                <Input
                  type="url"
                  name="imageUrl"
                  value={formData.imageUrl}
                  onChange={handleInputChange}
                  placeholder="https://example.com/image.jpg"
                  className="bg-card border-border text-white"
                />
                <p className="text-xs text-gray-400 mt-1">
                  Optional: URL for the market image
                </p>
              </div>

              {/* USDC Requirement Notice */}
              <div className="border-t border-white/10 pt-4 mt-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <p className="text-sm text-white mb-2">
                    <span className="font-semibold">Market Creation Fee: 20 USDC</span>
                  </p>
                  <p className="text-xs text-gray-300 leading-relaxed">
                    A deposit of 20 USDC is required to create a market. This ensures quality markets and prevents spam. 
                    Your deposit will be fully returned after the event period ends, regardless of market outcome.
                  </p>
                </div>
              </div>

              {/* Form Actions */}
              <div className="flex items-center justify-end gap-3 pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={handleClose}
                  className="border-white/20 text-white hover:bg-white/10"
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  className="rounded-full px-4 py-2 text-sm transition-all duration-200"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                    color: 'white',
                  }}
                >
                  Create Market
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Markets Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {markets.map((market) => (
          <CometCard key={market.id} rotateDepth={17.5} translateDepth={20}>
            <Link href={`/trade/${market.pair}`}>
              <div
                className="rounded-xl overflow-hidden transition-all duration-200 cursor-pointer h-full flex flex-col"
                style={{
                  backgroundColor: 'rgba(10, 10, 10, 0.7)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                  minHeight: '400px',
                }}
              >
                {/* Image - Top Half */}
                <div className="relative w-full h-[180px]">
                  <Image 
                    src={market.image} 
                    alt={market.title}
                    fill
                    className="object-cover"
                  />
                  <div className="absolute top-3 left-3">
                    <span 
                      className="px-3 py-1 rounded-full text-xs font-medium"
                      style={{
                        backgroundColor: 'rgba(10, 10, 10, 0.8)',
                        border: '1px solid rgba(255, 255, 255, 0.2)',
                        backdropFilter: 'blur(10px)',
                        color: 'white',
                        fontFamily: 'GT America Mono, monospace',
                      }}
                    >
                      {market.category}
                    </span>
                  </div>
                </div>

                {/* Bottom Half - Content */}
                <div className="flex flex-col flex-grow p-5">
                  <div className="mt-auto space-y-3">
                    <h3 className="text-white text-lg font-light" style={{ fontFamily: 'PP Editorial New, serif' }}>
                      {market.title}
                    </h3>
                    
                    <p className="text-gray-300 text-sm" style={{ fontFamily: 'GT America Mono, monospace' }}>
                      {market.question}
                    </p>

                    {/* Trade Button */}
                    <button
                      className="w-full py-2 rounded-full text-white text-sm font-medium transition-all duration-200"
                      style={{
                      backgroundColor: 'rgba(10, 10, 10, 0.7)',
                      border: '1px solid rgba(255, 255, 255, 0.1)',
                      backdropFilter: 'blur(10px)',
                      fontFamily: 'GT America Mono, monospace',
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
                      Trade Market
                    </button>
                  </div>
                </div>
              </div>
            </Link>
          </CometCard>
        ))}
      </div>

      {markets.length === 0 && (
        <div className="text-center py-16">
          <p className="text-gray-400 text-lg">No markets found matching your search.</p>
        </div>
      )}
    </div>
  );
}

