const { ethers } = require("ethers");
const RitualRegistry = require("../../abis/RitualRegistry.json");

module.exports = async (ritualID, payload) => {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.RITUAL_AGENT_KEY, provider);
  const registry = new ethers.Contract(
    process.env.REGISTRY_ADDRESS,
    RitualRegistry.abi,
    wallet
  );

  // Verify ritual in registry
  const isValid = await registry.validate(ritualID, payload);
  if (!isValid) throw new Error("RITUAL INVALID: CORRUPTED SIGNATURE");

  // Execute ritual-specific action
  switch (ritualID) {
    case "0xd4f...a1c": // Faucet ritual
      const { recipient } = JSON.parse(payload);
      await require("./FaucetAgent.js")(recipient);
      break;
    case "0xb73...e8f": // Vault ritual
      await require("./VaultUnlockAgent.js")(payload);
      break;
    default:
      throw new Error("UNKNOWN RITUAL");
  }
};
