import { readFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import {
  JsonRpcProvider, Wallet, Contract,
  keccak256, toUtf8Bytes, getBytes, parseUnits
} from "ethers";

// ---- load env
const {
  RPC_URL,
  SCAR_ADDR,
  REGISTRY_ADDR,
  AGENT_PK,
  RITUAL_NAME = "FAUCET_V1",
  RITUAL_DEADLINE_SECS = "600",
} = process.env;

if (!RPC_URL || !SCAR_ADDR || !REGISTRY_ADDR || !AGENT_PK) {
  throw new Error("Missing required env: RPC_URL, SCAR_ADDR, REGISTRY_ADDR, AGENT_PK");
}

// ---- ABIs
const ScarCoinAbi = JSON.parse(readFileSync("abis/ScarCoin.json", "utf8"));
const RegistryAbi = JSON.parse(readFileSync("abis/RitualRegistry.json", "utf8"));

// ---- basic contracts
const provider = new JsonRpcProvider(RPC_URL);
const agentWallet = new Wallet(AGENT_PK, provider);
const Scar = new Contract(SCAR_ADDR, ScarCoinAbi, agentWallet);
const Registry = new Contract(REGISTRY_ADDR, RegistryAbi, provider);

// ---- helpers
const RITUAL_ID = keccak256(toUtf8Bytes(RITUAL_NAME)); // bytes32
const DEADLINE_SECS = parseInt(RITUAL_DEADLINE_SECS, 10) || 600;

/** stable bytes for payload hashing (any JS obj → bytes) */
function packPayload(payload: unknown): Uint8Array {
  // canonical JSON → bytes; if you already have ABI-encoded bytes, pass directly
  const s = JSON.stringify(payload);
  return getBytes("0x" + Buffer.from(s, "utf8").toString("hex"));
}

/** generate 32-byte random nonce (bytes32) */
function newNonce(): string {
  return "0x" + randomBytes(32).toString("hex");
}

/** sha256-to-hex (optional, for idempotency keys outside chain) */
function sha256Hex(s: string): string {
  return createHash("sha256").update(s).digest("hex");
}

/** Build EIP-712 domain/types/value for ScarCoin.mintRitual */
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
    verifyingContract: SCAR_ADDR,
  } as const;

  const types = {
    MintRitual: [
      { name: "ritualId", type: "bytes32" },
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "deadline", type: "uint256" },
      { name: "payloadHash", type: "bytes" },
    ],
  } as const;

  const value = {
    ritualId: RITUAL_ID,
    to,
    amount: amountWei,
    nonce,
    deadline,
    payloadHash: getBytes(keccak256(payloadBytes)),
  } as const;

  return { domain, types, value };
}

/** Optional preflight using Registry.validate (view) */
async function validateOnRegistry(ritualId: string, nonce: string, payloadBytes: Uint8Array) {
  const [ok, agent] = await Registry.validate(ritualId, nonce, payloadBytes);
  return { ok: Boolean(ok), agent: String(agent) };
}

/**
 * Main API: mint via ritual
 * @param to recipient address
 * @param amount human string ("10.5") in SCAR units (assumes 18 decimals)
 * @param payload any JSON-serializable structure (or pass a hex string "0x..")
 */
export async function mintFaucet(to: string, amount: string, payload: unknown) {
  const amountWei = parseUnits(amount, 18);
  const nonce = newNonce();
  const deadline = Math.floor(Date.now() / 1000) + DEADLINE_SECS;

  const payloadBytes =
    typeof payload === "string" && payload.startsWith("0x")
      ? getBytes(payload)
      : packPayload(payload);

  // Optional preflight check
  const pre = await validateOnRegistry(RITUAL_ID, nonce, payloadBytes);
  if (!pre.ok) throw new Error("Registry.validate rejected the ritual (inactive or unknown)");
  // Not strictly necessary, but helps catch config mistakes:
  // console.log("Registry expects agent:", pre.agent);

  // Build EIP-712 and sign with agent key
  const { domain, types, value } = await buildTypedMint(to, amountWei, nonce, deadline, payloadBytes);
  const sig = await agentWallet.signTypedData(domain, types as any, value as any);

  // On-chain call
  const tx = await Scar.mintRitual(
    RITUAL_ID,
    to,
    amountWei,
    nonce,
    deadline,
    payloadBytes,
    sig,
    { gasLimit: 500_000n } // adjust if needed
  );
  const receipt = await tx.wait();

  const key = sha256Hex(`${receipt.hash}:${receipt.transactionIndex}`);
  return { txHash: receipt.hash, idempotencyKey: key, nonce, deadline };
}

// Example CLI usage:
// ts-node agents/faucet/minter.ts 0xYourAddress 5.0 '{"reason":"welcome","tier":1}'
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
