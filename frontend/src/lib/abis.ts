export async function loadAbi(name: 'ScarCoin' | 'RitualRegistry') {
  const res = await fetch(`/abis/${name}.json`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`ABI fetch failed: ${name} (${res.status})`);
  return res.json();
}
