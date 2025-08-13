import React, { useEffect, useMemo, useState } from 'react';
import { JsonRpcProvider, Contract } from 'ethers';
import { env } from './env';
import { loadAbi } from './lib/abis';

export default function App() {
  const [ready, setReady] = useState(false);
  const [decimals, setDecimals] = useState<number | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const provider = useMemo(() => new JsonRpcProvider(env.RPC_URL), []);

  useEffect(() => {
    (async () => {
      try {
        // fetch lean ABIs shipped at /public/abis
        const scarAbi = await loadAbi('ScarCoin');
        const scar = new Contract(env.SCAR_ADDR, scarAbi, provider);
        // try decimals() — if call fails, fall back to env or 0
        let d: number | null = null;
        try {
          d = Number(await scar.decimals());
          if (!Number.isFinite(d)) d = null;
        } catch {}
        setDecimals(d ?? (env.SCAR_DECIMALS ?? 0));
        setReady(true);
      } catch (e: any) {
        setErr(e?.message || String(e));
      }
    })();
  }, [provider]);

  return (
    <main style={{ fontFamily: 'Inter, system-ui, sans-serif', padding: 24, lineHeight: 1.4 }}>
      <h1>ScarCoin — Ritual Visualizer</h1>
      <p style={{ opacity: 0.8, marginTop: -4 }}>Production-ready Vercel deploy scaffold</p>

      <section style={{ marginTop: 16 }}>
        <h3>Configuration</h3>
        <ul>
          <li><b>RPC</b>: {env.RPC_URL}</li>
          <li><b>ScarCoin</b>: {env.SCAR_ADDR}</li>
          <li><b>RitualRegistry</b>: {env.REGISTRY_ADDR}</li>
          <li><b>Decimals</b>: {decimals ?? 'loading…'}</li>
        </ul>
      </section>

      <section style={{ marginTop: 16 }}>
        <h3>Status</h3>
        {err && <p style={{ color: 'crimson' }}>Error: {err}</p>}
        {!err && (ready ? <p>Ready ✅</p> : <p>Booting…</p>)}
        <p>ABIs are served from <code>/abis/ScarCoin.json</code> and <code>/abis/RitualRegistry.json</code>.</p>
      </section>
    </main>
  );
}
