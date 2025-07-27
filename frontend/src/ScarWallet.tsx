import React from 'react';

interface ScarWalletProps {
  balance: number;
}

/**
 * ScarWallet displays the current ScarCoin balance and exposes ritual triggers.
 * This is a placeholder React component that can be extended to include
 * transfer and ritual invocation logic via useRitualSync hooks.
 */
const ScarWallet: React.FC<ScarWalletProps> = ({ balance }) => {
  return (
    <div>
      <h2>ScarWallet</h2>
      <p>Balance: {balance} ∆</p>
      {/* TODO: Add buttons to initiate faucet and vault rituals */}
    </div>
  );
};

export default ScarWallet;
