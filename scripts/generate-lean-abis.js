/**
 * Generate minimal ABIs for the agent, avoiding oversized artifacts.
 * Produces: abis/lean/ScarCoin.json and abis/lean/RitualRegistry.json
 *
 * Run after `npx hardhat compile`.
 */
const fs = require("fs");
const path = require("path");

const ARTIFACTS_DIR = path.join(process.cwd(), "artifacts");
const OUT_DIR = path.join(process.cwd(), "abis", "lean");

if (!fs.existsSync(ARTIFACTS_DIR)) {
  console.error("Artifacts directory not found. Did you run `npx hardhat compile`?");
  process.exit(1);
}

fs.mkdirSync(OUT_DIR, { recursive: true });

function walk(dir, hits = []) {
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, hits);
    else hits.push(p);
  }
  return hits;
}

function findArtifact(contractName) {
  const files = walk(ARTIFACTS_DIR);
  // Hardhat usually stores at `artifacts/contracts/<File>.sol/<Contract>.json`
  const match = files.find(
    (p) =>
      p.endsWith(`${path.sep}${contractName}.json`) &&
      p.includes(`${path.sep}contracts${path.sep}`)
  );
  if (!match) {
    console.error(`Artifact for ${contractName} not found under artifacts/contracts/**/${contractName}.json`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(match, "utf8"));
}

/**
 * Keep only what the agent needs. Add `decimals` so the agent can detect token precision.
 */
function leanAbi(fullAbi, allowList) {
  const allow = new Set(allowList);
  return fullAbi.filter((entry) => {
    if (entry.type === "event" || entry.type === "function") return allow.has(entry.name);
    return false;
  });
}

// Load artifacts
const scar = findArtifact("ScarCoin");
const reg = findArtifact("RitualRegistry");

// Whitelist for agent usage
const SCAR_ALLOW = ["mintRitual", "setRegistry", "RitualTrigger", "decimals"];
const REG_ALLOW = ["registerRitual", "validate", "setActive"];

// Filter
const scarLean = leanAbi(scar.abi, SCAR_ALLOW);
const regLean = leanAbi(reg.abi, REG_ALLOW);

// Write outputs
const scarOut = path.join(OUT_DIR, "ScarCoin.json");
const regOut = path.join(OUT_DIR, "RitualRegistry.json");

fs.writeFileSync(scarOut, JSON.stringify(scarLean, null, 2));
fs.writeFileSync(regOut, JSON.stringify(regLean, null, 2));

console.log(`Lean ABI written: ${scarOut}`);
console.log(`Lean ABI written: ${regOut}`);
