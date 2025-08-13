declare namespace NodeJS {
  interface ProcessEnv {
    RPC_URL: string;
    SCAR_ADDR: string;
    REGISTRY_ADDR: string;
    AGENT_PK: string;
    RITUAL_NAME?: string;      // defaults to "FAUCET_V1"
    RITUAL_DEADLINE_SECS?: string; // defaults to 600
  }
}
