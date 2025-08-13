// copies abis/lean -> frontend/public/abis (monorepo-friendly)
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const src = path.join(repoRoot, 'abis', 'lean');
const dst = path.join(repoRoot, 'frontend', 'public', 'abis');

if (!fs.existsSync(src)) {
  console.warn('[copy-lean-abis] Source ABIs not found:', src, '(skipping)');
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
