// copies abis/lean -> frontend/public/abis (monorepo-friendly)
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const src = path.join(repoRoot, 'abis', 'lean');
const dst = path.join(repoRoot, 'frontend', 'public', 'abis');

const isCI = process.env.CI === 'true' || !!process.env.VERCEL;
if (!fs.existsSync(src)) {
  const msg = `[copy-lean-abis] Source ABIs not found at ${src}.
  Did you run 'npx hardhat compile && node scripts/generate-lean-abis.js' or download the CI artifact?`;
  if (isCI) { console.error(msg); process.exit(1); }
  console.warn(msg + ' (continuing for local dev)');
  process.exit(0);
}

fs.rmSync(dst, { recursive: true, force: true });
fs.mkdirSync(dst, { recursive: true });
for (const f of fs.readdirSync(src)) {
  if (f.endsWith('.json')) {
    fs.copyFileSync(path.join(src, f), path.join(dst, f));
  }
}
console.log('[copy-lean-abis] Copied lean ABIs to frontend/public/abis');
