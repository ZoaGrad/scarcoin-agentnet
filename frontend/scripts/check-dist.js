const fs = require('fs');
const path = require('path');
const idx = path.join(__dirname, '..', 'dist', 'index.html');
if (!fs.existsSync(idx)) {
  console.error('[check-dist] dist/index.html not found. Build likely failed or wrong output directory.');
  process.exit(1);
}
console.log('[check-dist] OK:', idx);
