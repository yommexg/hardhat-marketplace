const { ethers, network, deployments } = require("hardhat");
const { moveBlocks } = require("../utils/move-block");

const PRICE = ethers.utils.parseEther("0.1");

async function mint() {
  const basicNft = await ethers.getContract("BasicNft");
  console.log("Minting...");
  const mintTx = await basicNft.mintNft();
  const mintTxReceipt = await mintTx.wait(1);
  const tokenId = mintTxReceipt.events[0].args.tokenId;
  console.log("Token Id is " + tokenId.toString());
  console.log("NFT Address is" + basicNft.address);

  if (network.config.chainId == "31337") {
    await moveBlocks(2, (sleepAmount = 1000));
  }
}

mint()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
