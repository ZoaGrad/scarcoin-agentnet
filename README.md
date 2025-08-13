# ScarCoin Genesis Protocol

ScarCoin is a symbolic cryptocurrency and infrastructure protocol designed to explore new ways of connecting on‑chain events with off‑chain agent networks. It combines smart contracts, an on‑chain ritual registry, and a daemonized agent network to create responsive token flows.

This repository contains the hardened, production-ready version of the protocol.

## Hardened Features

The protocol has been hardened with a focus on security, auditability, and a professional development workflow.

- **Secure Ritual Registry**: The `RitualRegistry` contract is now owned and managed by a `CURATOR_ROLE`, preventing unauthorized ritual registration. It is also `Pausable` for emergency stops.
- **EIP-712 Based Minting**: The `ScarCoin` contract now uses EIP-712 signatures for all minting operations. This ensures that only authorized, off-chain agents can trigger the creation of new tokens, eliminating the insecure "transfer-as-mint" pattern.
- **Robust Agent Minter**: The new Faucet Minter agent (`agents/faucet/minter.ts`) is a typed, production-grade script that correctly signs EIP-712 messages and dynamically detects the token's decimal precision.
- **Continuous Integration**: The repository includes a GitHub Actions workflow that automatically compiles contracts and generates lean ABIs, ensuring code is always in a buildable state.
- **Cloud Development Environment**: A Dev Container configuration is provided for a consistent, one-click development setup using GitHub Codespaces.

## Repository Structure

The repository has been updated to reflect the new architecture and development tools.

```
scarcoin-agentnet/
├── .github/
│   └── workflows/
│       └── ci.yml                   # GitHub Actions CI workflow
├── .devcontainer/
│   ├── devcontainer.json            # Dev Container configuration
│   └── setup-foundry.sh             # Foundry installer for Dev Container
├── contracts/
│   ├── core/
│   │   └── ScarCoin.sol             # Hardened EIP-712 token
│   └── rituals/
│       └── RitualRegistry.sol       # Hardened, role-based registry
├── agents/
│   └── faucet/
│       ├── minter.ts                # Secure, EIP-712 Faucet Minter agent
│       └── env.d.ts                 # TypeScript env definitions
├── scripts/
│   ├── deploy.js                    # Updated Hardhat deployment script
│   └── generate-lean-abis.js        # Script to generate minimal ABIs for the agent
├── abis/
│   ├── lean/                        # Lean ABIs for agent use
│   └── ...
├── frontend/                        # (Unchanged) React/Next.js interface
├── .env.example                     # Environment variables
├── hardhat.config.js                # Hardhat config (solc 0.8.24)
└── BOOK_OF_RITUALS.md               # (Outdated) Project notes
```

## Getting Started

The recommended way to work with this repository is to use a cloud-based development environment, which avoids local setup issues.

### Recommended Setup: GitHub Codespaces

1.  Click the "Code" button on the GitHub repository page.
2.  Select the "Codespaces" tab.
3.  Click "Create codespace on main".
4.  This will launch a fully configured development environment in your browser with all dependencies (Node.js, Foundry) pre-installed. All commands below will work out-of-the-box.

### Build

The contracts can be built using the provided npm script, which runs Hardhat and then generates the lean ABIs for the agent.

```bash
npm run build:abi
```
This will populate the `artifacts/` and `abis/lean/` directories. The CI pipeline also runs this on every push.

### Run the Agent

The Faucet Minter agent requires several environment variables to be set. Copy `.env.example` to `.env` and fill in the following:

- `RPC_URL`: URL for an Ethereum JSON-RPC provider.
- `SCAR_ADDR`: The deployed `ScarCoin` contract address.
- `REGISTRY_ADDR`: The deployed `RitualRegistry` contract address.
- `AGENT_PK`: The private key of the authorized agent wallet.

Once configured, you can test a mint from the command line:
```bash
npx ts-node agents/faucet/minter.ts <RECIPIENT_ADDRESS> <AMOUNT> '{"reason":"test"}'
```

### Local Verification (Foundry)

For advanced local testing and verification without relying on the Node.js agent, you can use Foundry.

1.  **Start a local chain:**
    ```bash
    anvil
    ```
2.  **Deploy the contracts:**
    ```bash
    # Deploy Registry
    forge create src/RitualRegistry.sol:RitualRegistry --private-key <YOUR_PK>

    # Deploy ScarCoin, passing the Registry's address
    forge create src/ScarCoin.sol:ScarCoin --constructor-args <REGISTRY_ADDRESS> --private-key <YOUR_PK>
    ```
3.  **Use `cast` to interact with the contracts:**
    ```bash
    # Register a ritual, sign a message, and call mintRitual
    cast send ...
    ```

## License

ScarCoin is released under the MIT License.
