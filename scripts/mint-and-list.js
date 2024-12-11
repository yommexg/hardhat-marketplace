const { ethers, network, deployments } = require("hardhat");
const { moveBlocks } = require("../utils/move-block");

const PRICE = ethers.utils.parseEther("0.1");

async function mintAndList() {
  // await deployments.fixture(["basicnft", "nftmarketplace"]);
  const nftMarketPlace = await ethers.getContract("NftMarketPlace");
  const basicNft = await ethers.getContract("BasicNft");
  console.log("Minting...");
  const mintTx = await basicNft.mintNft();
  const mintTxReceipt = await mintTx.wait(1);
  const tokenId = mintTxReceipt.events[0].args.tokenId;
  console.log(tokenId.toString());
  console.log("Approving Nft....");

  const approvalTx = await basicNft.approve(nftMarketPlace.address, tokenId);
  await approvalTx.wait(1);
  console.log("Listing NFT...");
  const tx = await nftMarketPlace.listItem(basicNft.address, tokenId, PRICE);
  await tx.wait(1);
  console.log("Listed");

  if (network.config.chainId == "31337") {
    await moveBlocks(2, (sleepAmount = 1000));
  }
}

mintAndList()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
