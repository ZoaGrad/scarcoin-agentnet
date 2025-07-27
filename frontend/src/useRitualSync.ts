import { useEffect } from 'react';
import { ethers } from 'ethers';

/**
 * useRitualSync - React hook to subscribe to on-chain RitualTrigger events.
 * This placeholder hook listens for the `RitualTrigger` event emitted by the
 * ScarCoin contract and invokes a callback with the ritual ID and context.
 *
 * @param contractAddress Address of the ScarCoin contract
 * @param abi ABI for the contract (RitualRegistry or ScarCoin)
 * @param onRitual Callback invoked when a ritual trigger occurs
 */
const useRitualSync = (
  contractAddress: string,
  abi: any,
  onRitual: (ritualID: string, context: any) => void
) => {
  useEffect(() => {
    if (!contractAddress) return;

    const provider = new ethers.providers.WebSocketProvider(
      (process.env.NEXT_PUBLIC_RPC_URL as string) || ''
    );
    const contract = new ethers.Contract(contractAddress, abi, provider);

    const handler = (ritualID: string, context: any) => {
      onRitual(ritualID, context);
    };

    contract.on('RitualTrigger', handler);

    return () => {
      contract.off('RitualTrigger', handler);
      provider?.destroy?.();
    };
  }, [contractAddress, abi, onRitual]);
};

export default useRitualSync;
