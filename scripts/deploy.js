// scripts/deploy.js
const { ethers, run } = require('hardhat');

async function main() {
  // Deploy ScarCoin contract
  const ScarCoin = await ethers.getContractFactory("ScarCoin");
  const scarCoin = await ScarCoin.deploy();
  await scarCoin.deployed();

  // Deploy RitualRegistry contract with ScarCoin address
  const RitualRegistry = await ethers.getContractFactory("RitualRegistry");
  const registry = await RitualRegistry.deploy(scarCoin.address);
  await registry.deployed();

  // Register default ritual ID and agent address (placeholder values)
  await registry.registerRitual(
    "faucet",
    "0xd4f...a1c",
    process.env.FAUCET_AGENT_ADDRESS
  );

  console.log("\u2206 ScarCoin deployed to:", scarCoin.address);
  console.log("\uD83D\uDD2E RitualRegistry deployed to:", registry.address);

  // Verify ScarCoin on the network explorer
  await run("verify:verify", {
    address: scarCoin.address,
    constructorArguments: [],
  });
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
