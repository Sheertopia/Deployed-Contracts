require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");

const { API_URL, API_URL_ETH, PRIVATE_KEY_ETH, ETHERSCAN_KEY, PRIVATE_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  defaultNetwork: "ethereum_mainnet",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    polygon_mumbai: {
      url: API_URL,
      accounts: [`0x${PRIVATE_KEY_ETH}`],
    },
    ethereum_mainnet: {
      url: API_URL_ETH,
      accounts: [`0x${PRIVATE_KEY_ETH}`],
    },
    goerli: {
      url: API_URL_ETH,
      accounts: [`0x${PRIVATE_KEY_ETH}`],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_KEY
  },
};
