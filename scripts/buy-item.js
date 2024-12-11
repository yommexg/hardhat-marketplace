const { network } = require("hardhat");
const { moveBlocks } = require("../utils/move-block");

const TOKEN_ID = 2;

async function buyItem() {
  //   await deployments.fixture(["basicnft", "nftmarketplace"]);
  const nftMarketPlace = await ethers.getContract("NftMarketPlace");
  const basicNft = await ethers.getContract("BasicNft");
  const listing = await nftMarketPlace.getListing(basicNft.address, TOKEN_ID);
  const price = await listing.price.toString();

  console.log("Buying NFT...");
  const tx = await nftMarketPlace.buyItem(basicNft.address, TOKEN_ID, {
    value: price,
  });
  await tx.wait(1);
  console.log("NFT Bought");

  if (network.config.chainId == "31337") {
    await moveBlocks(2, (sleepAmount = 1000));
  }
}

buyItem()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
