/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { FloatingNav } from '@/src/ui/FloatingNavbar';
import { IconCurrencyBitcoin, IconTrophy, IconBriefcase, IconNews, IconHome } from '@tabler/icons-react';
import { WalletButton } from '@/src/components/WalletButton';

export function Navbar() {
  const navItems = [
    {
      name: "Home",
      link: "/",
      icon: <IconHome className="h-4 w-4 text-white" />,
    },
    {
      name: "Markets",
      link: "/markets",
      icon: <IconCurrencyBitcoin className="h-4 w-4 text-white" />,
    },
    {
      name: "Rewards",
      link: "/rewards",
      icon: <IconTrophy className="h-4 w-4 text-white" />,
    },
    {
      name: "News",
      link: "/news",
      icon: <IconNews className="h-4 w-4 text-white" />,
    },
    {
      name: "Portfolio",
      link: "/learn",
      icon: <IconBriefcase className="h-4 w-4 text-white" />,
    },
  ];

  return (
    <>
      <FloatingNav navItems={navItems} />
      <WalletButton />
    </>
  );
}
