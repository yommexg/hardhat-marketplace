const { network } = require("hardhat");
const { moveBlocks } = require("../utils/move-block");

const TOKEN_ID = "0";

async function cancelItem() {
  await deployments.fixture(["basicnft", "nftmarketplace"]);
  const nftMarketPlace = await ethers.getContract("NftMarketPlace");
  const basicNft = await ethers.getContract("BasicNft");
  console.log("Canceling NFT...");
  const tx = await nftMarketPlace.cancelItem(basicNft.address, TOKEN_ID);
  await tx.wait(1);
  console.log("NFT Cancelled");

  if (network.config.chainId == "31337") {
    await moveBlocks(2, (sleepAmount = 1000));
  }
}

cancelItem()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
