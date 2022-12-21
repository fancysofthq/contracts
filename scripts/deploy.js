import hardhat from "hardhat";
const { ethers } = hardhat;

async function deploy(contractName, deployOptions = {}, args = []) {
  const factory = await ethers.getContractFactory(contractName, deployOptions);

  const balance = await factory.signer.getBalance();
  console.log(`Balance: ${ethers.utils.formatEther(balance)}`);

  const deployTx = factory.getDeployTransaction(...args);

  const estimatedGas = await factory.signer.estimateGas(deployTx);
  const gasPrice = await factory.signer.getGasPrice();

  const deploymentPriceWei = gasPrice.mul(estimatedGas);
  console.log(`Estimated gas for ${contractName}: ${estimatedGas}`);
  console.log(
    `Estimated gas price for ${contractName}: ${ethers.utils.formatEther(
      deploymentPriceWei
    )}`
  );

  const instance = await factory.deploy(...args);
  await instance.deployed();
  console.log(contractName, "deployed to", instance.address);
  console.log("Tx", instance.deployTransaction.hash);

  return instance;
}

async function main() {
  const ipnft721Soulbound = await deploy(
    "IPNFT721Soulbound",
    {
      libraries: {
        LibIPNFT: process.env.ETH_LIB_IPNFT_ADDRESS,
      },
    },
    ["ACME", "ACME"] // Change this to your own name and symbol
  );

  const ipft1155Redeemable = await deploy("IPNFT1155Redeemable", {
    libraries: {
      LibIPNFT: process.env.ETH_LIB_IPNFT_ADDRESS,
    },
  });

  const nftFair = await deploy("NFTFair");
  const nftHype = await deploy("NFTHype");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
