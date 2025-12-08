/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import Link from 'next/link';
import { Button } from '@/src/ui/Button';
import { Tabs, TabsList, TabsTrigger } from '@/src/ui/Tabs';
import { ChartIcon } from '@/src/components/Icons';
import { useChartStore } from '@/src/utils/store/chartStore';

export default function ChartControl() {
  const { interval, chartType, setInterval, setChartType } =
    useChartStore();

  return (
    <div className="border-b border-border/20 flex items-center p-2">
      <div className="flex items-center gap-4">
        <Tabs
          defaultValue={chartType}
          value={chartType}
          onValueChange={(value) =>
            setChartType(value as 'chart' | 'book' | 'depth' | 'equalizer')
          }
        >
          <TabsList className="bg-background border border-border/20 rounded-md">
            <TabsTrigger
              value="chart"
              className="data-[state=active]:bg-secondary rounded-md"
            >
              <ChartIcon className="h-4 w-4 mr-1" />
              Chart
            </TabsTrigger>
          </TabsList>
        </Tabs>

        <div className="flex items-center gap-2 text-sm">
          <Button
            variant={interval === '1m' ? 'secondary' : 'ghost'}
            size="sm"
            className="px-2 py-1 h-8 rounded-md"
            onClick={() => setInterval('1m')}
          >
            1m
          </Button>
          <Button
            variant={interval === '1h' ? 'secondary' : 'ghost'}
            size="sm"
            className="px-2 py-1 h-8 rounded-md"
            onClick={() => setInterval('1h')}
          >
            1h
          </Button>
          <Button
            variant={interval === '1d' ? 'secondary' : 'ghost'}
            size="sm"
            className="px-2 py-1 h-8 rounded-md"
            onClick={() => setInterval('1d')}
          >
            1d
          </Button>
          <Button
            variant={interval === '1w' ? 'secondary' : 'ghost'}
            size="sm"
            className="px-2 py-1 h-8 rounded-md"
            onClick={() => setInterval('1w')}
          >
            1w
          </Button>
        </div>

        {/* Dashboard Button */}
        <Link href="/dashboard/nyc">
          <button
            className="rounded-full px-4 py-2 text-sm text-white transition-all duration-200"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.7)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
              e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
              e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.1)';
            }}
          >
            Dashboard
          </button>
        </Link>
      </div>

      {/* <div className="ml-auto flex items-center gap-2">
        <div>
          <div className="bg-background border border-border/20 rounded-md">
            <Button
              variant={view === 'chat' ? 'secondary' : 'ghost'}
              className="rounded-md hover:cursor-pointer"
              onClick={toggleView}
            >
              <MessageCircle className="h-4 w-4 mr-1" />
              Live Chat
            </Button>
          </div>
        </div>
      </div> */}
    </div>
  );
}
