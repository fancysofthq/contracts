require("@nomiclabs/hardhat-waffle");
require("dotenv").config();
const ethers = require("ethers");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      chainId: 1337,
    },
    hardhat: {
      chainId: 1337,
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.ETH_PRIVATE_KEY || ethers.constants.HashZero],
    },
  },
};
