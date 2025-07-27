# Book of Rituals

This manual serves as a guide to the ScarCoin Genesis Protocol. It contains instructions and guidelines for performing rituals, setting up the environment, and interacting with the ScarCoin infrastructure.

## Ritual Overview
ScarCoin's ecosystem is built around rituals that are codified in smart contracts and executed by agents. Each ritual has a unique ID, metadata, and specific execution logic. The RitualRegistry contract is used to register new rituals and validate them.

### Faucet Ritual
The faucet ritual is used to mint a small amount of ScarCoin to a recipient. Use the faucet endpoint to trigger this ritual.

**Example:**
```bash
curl -X POST https://abacus-agentnet.example/faucet -d '{"recipient":"0xYourAddressHere"}'
```

### Vault Ritual
The vault ritual unlocks a vault or performs a special action defined off‑chain. Use the vault endpoint with the appropriate payload.

## Environment Variables
See `.env.example` for environment variables used by the scripts and agents. Copy the file to `.env` and fill in the required values before running scripts.

## Deployment Guide
Use the provided `scripts/deploy.js` to deploy ScarCoin and the ritual registry to your test network. Make sure to set up your Hardhat configuration and environment variables.

## Agent Network
Run `scripts/ritual-boot.sh` to launch the ritual agents. The daemon spawns multiple Node processes to listen and react to ritual triggers.

## Frontend
The `frontend` directory contains a React app with components such as `ScarWallet`, `RitualVisualizer`, and the `useRitualSync` hook. Use these as a base for building your user interface.

---

This book is a starting point for exploring the ScarCoin ritual ecosystem. Feel free to expand, annotate, and build upon it as your protocol evolves.
