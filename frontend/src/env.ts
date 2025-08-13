function must(k: string, v: string | undefined): string {
  if (!v) throw new Error(`Missing required env: ${k}`);
  return v;
}

const isVite = typeof import.meta !== 'undefined' && (import.meta as any).env;
const V = isVite ? (import.meta as any).env : ({} as any);

export const env = {
  RPC_URL: must('VITE_RPC_URL', V.VITE_RPC_URL),
  SCAR_ADDR: must('VITE_SCAR_ADDR', V.VITE_SCAR_ADDR),
  REGISTRY_ADDR: must('VITE_REGISTRY_ADDR', V.VITE_REGISTRY_ADDR),
  SCAR_DECIMALS: V.VITE_SCAR_DECIMALS ? Number(V.VITE_SCAR_DECIMALS) : undefined
} as const;
