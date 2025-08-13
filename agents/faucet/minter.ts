// agents/faucet/minter.ts
import { readFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import {
  JsonRpcProvider,
  Wallet,
  Contract,
  keccak256,
  toUtf8Bytes,
  getBytes,
  parseUnits
} from "ethers";

/**
 * Required ENV:
 *  - RPC_URL
 *  - SCAR_ADDR
 *  - REGISTRY_ADDR
 *  - AGENT_PK
 * Optional:
 *  - RITUAL_NAME (default "FAUCET_V1")
 *  - RITUAL_DEADLINE_SECS (default "600")
 */
const {
  RPC_URL,
  SCAR_ADDR,
  REGISTRY_ADDR,
  AGENT_PK,
  RITUAL_NAME = "FAUCET_V1",
  RITUAL_DEADLINE_SECS = "600"
} = process.env;

if (!RPC_URL || !SCAR_ADDR || !REGISTRY_ADDR || !AGENT_PK) {
  throw new Error("Missing env: RPC_URL, SCAR_ADDR, REGISTRY_ADDR, AGENT_PK");
}

// Load lean ABIs produced by scripts/generate-lean-abis.js
const ScarCoinAbi = JSON.parse(readFileSync(new URL("../../abis/lean/ScarCoin.json", import.meta.url)));
const RegistryAbi = JSON.parse(readFileSync(new URL("../../abis/lean/RitualRegistry.json", import.meta.url)));

const provider = new JsonRpcProvider(RPC_URL);
const agentWallet = new Wallet(AGENT_PK, provider);
const Scar = new Contract(SCAR_ADDR, ScarCoinAbi, agentWallet);
const Registry = new Contract(REGISTRY_ADDR, RegistryAbi, provider);

const RITUAL_ID = keccak256(toUtf8Bytes(RITUAL_NAME));
const DEADLINE_SECS = parseInt(RITUAL_DEADLINE_SECS, 10) || 600;

/** Canonical JSON → bytes (or pass pre-encoded 0x.. string) */
function packPayload(payload: unknown): Uint8Array {
  if (typeof payload === "string" && payload.startsWith("0x")) {
    return getBytes(payload);
  }
  const s = JSON.stringify(payload);
  return getBytes("0x" + Buffer.from(s, "utf8").toString("hex"));
}

function newNonce(): string {
  return "0x" + randomBytes(32).toString("hex");
}

function sha256Hex(s: string): string {
  return createHash("sha256").update(s).digest("hex");
}

/** Resolve decimals dynamically, with safe fallbacks. */
let _decimalsCache: number | null = null;
async function getScarDecimals(): Promise<number> {
  if (_decimalsCache !== null) return _decimalsCache;
  try {
    // Requires "decimals" in lean ABI
    const d = await Scar.decimals();
    const n = Number(d);
    if (Number.isFinite(n) && n >= 0 && n <= 36) {
      _decimalsCache = n;
      return n;
    }
  } catch (e) {
    // ignore, fall through to fallback
  }
  // Fallback preference: 18 (ERC20 norm). If you truly use 0-decimals, change order.
  _decimalsCache = 18;
  return _decimalsCache;
}

async function buildTypedMint(
  to: string,
  amountWei: bigint,
  nonce: string,
  deadline: number,
  payloadBytes: Uint8Array
) {
  const net = await provider.getNetwork();
  const domain = {
    name: "ScarCoin",
    version: "1",
    chainId: Number(net.chainId),
    verifyingContract: SCAR_ADDR
  } as const;

  const types = {
    MintRitual: [
      { name: "ritualId", type: "bytes32" },
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "deadline", type: "uint256" },
      { name: "payloadHash", type: "bytes" }
    ]
  } as const;

  const value = {
    ritualId: RITUAL_ID,
    to,
    amount: amountWei,
    nonce,
    deadline,
    payloadHash: getBytes(keccak256(payloadBytes))
  } as const;

  return { domain, types, value };
}

async function validateOnRegistry(ritualId: string, nonce: string, payloadBytes: Uint8Array) {
  const [ok, agent] = await Registry.validate(ritualId, nonce, payloadBytes);
  return { ok: Boolean(ok), agent: String(agent) };
}

/**
 * Submit a ritual mint.
 * @param to recipient address
 * @param amount human string (e.g., "1.0") — scaled using live decimals()
 * @param payload JSON object or hex "0x.." pre-encoded bytes
 */
export async function mintFaucet(to: string, amount: string, payload: unknown) {
  const decimals = await getScarDecimals();
  const amountWei = parseUnits(amount, decimals);

  const nonce = newNonce();
  const deadline = Math.floor(Date.now() / 1000) + DEADLINE_SECS;
  const payloadBytes = packPayload(payload);

  // Optional preflight
  const pre = await validateOnRegistry(RITUAL_ID, nonce, payloadBytes);
  if (!pre.ok) throw new Error("Registry.validate rejected (inactive/unknown ritual).");

  // EIP-712 signature by agent
  const { domain, types, value } = await buildTypedMint(to, amountWei, nonce, deadline, payloadBytes);
  const sig = await agentWallet.signTypedData(domain as any, types as any, value as any);

  // On-chain call
  const tx = await Scar.mintRitual(
    RITUAL_ID,
    to,
    amountWei,
    nonce,
    deadline,
    payloadBytes,
    sig,
    { gasLimit: 500_000n }
  );
  const receipt = await tx.wait();

  const idempotencyKey = sha256Hex(`${receipt.hash}:${receipt.transactionIndex}`);
  return { txHash: receipt.hash, idempotencyKey, nonce, deadline, decimals };
}

// CLI usage:
// ts-node agents/faucet/minter.ts 0xRecipient 1.0 '{"reason":"welcome"}'
if (import.meta.url === `file://${process.argv[1]}`) {
  (async () => {
    const [to, amount, json] = process.argv.slice(2);
    if (!to || !amount) {
      console.error("Usage: ts-node agents/faucet/minter.ts <to> <amount> [jsonPayload]");
      process.exit(1);
    }
    const payload = json ? JSON.parse(json) : { reason: "faucet" };
    const res = await mintFaucet(to, amount, payload);
    console.log("Mint submitted:", res);
  })().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
