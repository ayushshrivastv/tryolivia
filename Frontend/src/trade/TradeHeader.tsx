/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useEffect, useState } from 'react';
import { getTicker } from '@/src/utils/httpClient';
import { MarketIcon } from '@/src/market/MarketIcon';
import { SignalingManager } from '@/src/utils/SignalingManager';
import { TickerPayload } from '@/src/utils/types';

interface TradeHeaderProps {
  baseCurrency: string;
  quoteCurrency: string;
}

export default function TradeHeader({
  baseCurrency,
  quoteCurrency,
}: TradeHeaderProps) {
  const isNYCMayorMarket = baseCurrency.includes('NYC-MAYOR') || baseCurrency === 'NYC-MAYOR';
  const [name, setName] = useState<string>();
  const [price, setPrice] = useState<string>('');
  const [priceChange, setPriceChange] = useState<number>(0);
  const [prevPrice, setPrevPrice] = useState<number | null>(null);
  const [animatedPercentage, setAnimatedPercentage] = useState<number>(88.8);
  const [animatedUsd, setAnimatedUsd] = useState<number>(600);

  useEffect(() => {
    const getTickerData = async () => {
      const data = await getTicker(`${baseCurrency}`);
      console.log('trade header data: ', data);
      setName(data.name);
    };

    getTickerData();
  }, [baseCurrency, quoteCurrency]);
  const market = `${baseCurrency}${quoteCurrency}`;
  const room = `ticker@${baseCurrency}${quoteCurrency}` as const;

  useEffect(() => {
    const onTicker = (data: TickerPayload) => {
      const { p } = data.data;

      if (p) {
        const currentPrice = parseFloat(p);
        setPrice(p);

        if (prevPrice !== null) {
          const change = ((currentPrice - prevPrice) / prevPrice) * 100;
          setPriceChange(parseFloat(change.toFixed(2)));
        }

        setPrevPrice(currentPrice);
      }
    };

    const mgr = SignalingManager.getInstance();

    mgr.registerTickerCallback(room, onTicker);
    mgr.subscribe(room);

    return () => {
      mgr.deRegisterTickerCallback(room, onTicker);
      mgr.unsubscribe(room);
    };
  }, [market, room, prevPrice]);

  // Continuously update percentage (88% to 92%) for NYC Mayor market
  useEffect(() => {
    if (!isNYCMayorMarket) return;

    const interval = setInterval(() => {
      // Generate a random value between 88 and 92
      const randomPercentage = 88 + (Math.random() * 4); // 88 to 92
      setAnimatedPercentage(randomPercentage);
    }, 1000); // Update every second

    return () => clearInterval(interval);
  }, [isNYCMayorMarket]);

  // Continuously update USD value ($600 to $800)
  useEffect(() => {
    const interval = setInterval(() => {
      // Generate a random value between 600 and 800
      const randomUsd = 600 + (Math.random() * 200); // 600 to 800
      setAnimatedUsd(randomUsd);
    }, 1000); // Update every second

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex items-center justify-between px-4 py-3 border-b border-border/20">
      <div className="flex items-center">
        <div className="flex items-center gap-3 mr-8">
          <MarketIcon base_asset={baseCurrency} />
          <div>
            <h2 className="text-lg font-semibold">{name || `${baseCurrency}${quoteCurrency}`}</h2>
            <p className="text-xs text-muted-foreground">
              SOLANA
            </p>
          </div>
        </div>

        <div className="flex items-center">
          <div>
            <div className="text-xl font-bold">
              {isNYCMayorMarket 
                ? `${animatedPercentage.toFixed(1)}%`
                : `${(parseFloat(price) * 100).toFixed(2)}%`}
            </div>

            <div className="text-xs text-green-500">{`$${animatedUsd.toFixed(2)}`}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
