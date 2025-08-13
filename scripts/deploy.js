// scripts/deploy.js
const { ethers, run } = require("hardhat");
const { keccak256, toUtf8Bytes, ZeroHash, Wallet } = require("ethers");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy RitualRegistry contract
  const RitualRegistry = await ethers.getContractFactory("RitualRegistry");
  const registry = await RitualRegistry.deploy(deployer.address);
  await registry.waitForDeployment(); // ethers v6 syntax
  const registryAddress = await registry.getAddress();
  console.log("\uD83D\uDD2E RitualRegistry deployed to:", registryAddress);

  // Deploy ScarCoin contract with RitualRegistry address
  const ScarCoin = await ethers.getContractFactory("ScarCoin");
  const scarCoin = await ScarCoin.deploy(registryAddress);
  await scarCoin.waitForDeployment(); // ethers v6 syntax
  const scarCoinAddress = await scarCoin.getAddress();
  console.log("\u2206 ScarCoin deployed to:", scarCoinAddress);

  // Grant the SCARCOIN_ROLE to the ScarCoin contract
  console.log("Granting SCARCOIN_ROLE to ScarCoin contract...");
  const scarCoinRole = keccak256(toUtf8Bytes("SCARCOIN_ROLE"));
  const grantRoleTx = await registry.grantRole(scarCoinRole, scarCoinAddress);
  await grantRoleTx.wait();
  console.log("SCARCOIN_ROLE granted successfully.");

  // Register the default Faucet ritual
  const ritualName = process.env.RITUAL_NAME || "FAUCET_V1";
  const ritualId = keccak256(toUtf8Bytes(ritualName));

  if (!process.env.AGENT_PK) {
    throw new Error("AGENT_PK environment variable is not set.");
  }
  // The agent address is the public address of the AGENT_PK
  const agentWallet = new Wallet(process.env.AGENT_PK);
  const agentAddress = agentWallet.address;

  const schema = ZeroHash; // Placeholder schema

  console.log(`Registering ritual "${ritualName}" (ID: ${ritualId}) for agent ${agentAddress}...`);
  const tx = await registry.registerRitual(ritualId, agentAddress, schema);
  await tx.wait();
  console.log("Ritual registered successfully.");

  // Wait for a few blocks for Etherscan to index the contracts
  console.log("Waiting for 30 seconds for block confirmations before verification...");
  await new Promise(resolve => setTimeout(resolve, 30000));

  // Verify RitualRegistry
  try {
    console.log("Verifying RitualRegistry...");
    await run("verify:verify", {
      address: registryAddress,
      constructorArguments: [deployer.address],
    });
     console.log("Verification successful for RitualRegistry.");
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
        console.log("RitualRegistry is already verified.");
    } else {
        console.error("Verification failed for RitualRegistry:", e.message);
    }
  }

  // Verify ScarCoin
  try {
    console.log("Verifying ScarCoin...");
    await run("verify:verify", {
      address: scarCoinAddress,
      constructorArguments: [registryAddress],
    });
    console.log("Verification successful for ScarCoin.");
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
        console.log("ScarCoin is already verified.");
    } else {
        console.error("Verification failed for ScarCoin:", e.message);
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
