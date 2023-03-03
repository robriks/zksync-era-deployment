import * as dotenv from 'dotenv';
dotenv.config();
import { utils, Wallet } from "zksync-web3";
import { BigNumber } from 'ethers';
import * as ethers from 'ethers';
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Pikapool Settlement contract`);

  // Initialize the wallet.
  const wallet = new Wallet(`${process.env.PK}`);

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("Settlement");

  // Deposit some funds to L2 in order to be able to perform L2 transactions.
  const depositAmount = ethers.utils.parseEther("0.05");
  const depositHandle = await deployer.zkWallet.deposit({
    to: deployer.zkWallet.address,
    token: utils.ETH_ADDRESS,
    amount: depositAmount,
  });
  // Wait until the deposit is processed on zkSync
  await depositHandle.wait();

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const settlementContract = await deployer.deploy(artifact, ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', 30]); //BigNumber.from(ethers.utils.getAddress('0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6'))]

  // Show the contract info.
  const contractAddress = settlementContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}
