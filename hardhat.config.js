// Hardhat configuration file for ScarCoin AgentNet
// This configuration uses environment variables defined in .env (see .env.example)

require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('dotenv').config();

const {
  RPC_URL,
  RITUAL_AGENT_KEY,
  ETHERSCAN_API_KEY
} = process.env;

module.exports = {
  solidity: '0.8.20',
  networks: {
    // Polygon Mumbai testnet configuration
    mumbai: {
      url: RPC_URL || '',
      accounts: RITUAL_AGENT_KEY ? [RITUAL_AGENT_KEY] : [],
    },
    // Ethereum Sepolia testnet configuration
    sepolia: {
      url: RPC_URL || '',
      accounts: RITUAL_AGENT_KEY ? [RITUAL_AGENT_KEY] : [],
    },
  },
  etherscan: {
    // API key for contract verification (Etherscan or Polygonscan)
    apiKey: ETHERSCAN_API_KEY || '',
  },
};
