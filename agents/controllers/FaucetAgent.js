const { ethers } = require("ethers");
const ScarCoin = require("../../abis/ScarCoin.json");

module.exports = async (recipient) => {
  // Create provider and wallet using environment variables
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.FAUCET_AGENT_KEY, provider);

  // Connect to ScarCoin contract
  const scarCoin = new ethers.Contract(
    process.env.SC_COIN_ADDRESS,
    ScarCoin.abi,
    wallet
  );

  // Mint 1 ∆ (using transfer for simplicity)
  const amount = 1;
  const tx = await scarCoin.transfer(recipient, amount);
  await tx.wait();
};
