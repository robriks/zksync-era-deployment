import * as dotenv from 'dotenv';
dotenv.config();
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";

module.exports = {
  zksolc: {
    version: "1.3.1",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkTestnet",
  networks: {
    zkTestnet: {
      url: "https://zksync2-testnet.zksync.dev", // URL of the zkSync network RPC
      ethNetwork: `${process.env.ZKTESTNET_RPC}`,
      zksync: true,
    },
  },
  solidity: {
    version: "0.8.17",
  },
};
