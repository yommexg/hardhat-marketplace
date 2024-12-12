const { ethers, network } = require("hardhat");
const fs = require("fs");

const frontEndContractFile = "../nextJs/constants/networkMapping.json";
const frontEndAbiLocation = "../nextJs/constants/";

module.exports = async function () {
  if (process.env.UPDATE_FRONT_END) {
    console.log("updating front end...");
    await updateContractAddresses();
    await updateAbi();
  }
};

async function updateAbi() {
  const nftMarketPlace = await ethers.getContract("NftMarketPlace");
  fs.writeFileSync(
    `${frontEndAbiLocation}NftMarketPlace.json`,
    nftMarketPlace.interface.format(ethers.utils.FormatTypes.json)
  );

  const basicNft = await ethers.getContract("BasicNft");
  fs.writeFileSync(
    `${frontEndAbiLocation}BasicNft.json`,
    basicNft.interface.format(ethers.utils.FormatTypes.json)
  );
}

async function updateContractAddresses() {
  const nftMarketPlace = await ethers.getContract("NftMarketPlace");
  const chainId = network.config.chainId;
  const contractAddresses = JSON.parse(
    fs.readFileSync(frontEndContractFile, "utf8")
  );
  if (chainId in contractAddresses) {
    if (
      !contractAddresses[chainId]["NftMarketPlace"].includes(
        nftMarketPlace.address
      )
    ) {
      contractAddresses[chainId]["NftMarketPlace"].push(nftMarketPlace.address);
    }
  } else {
    contractAddresses[chainId] = {
      NftMarketPlace: [nftMarketPlace.address],
    };
  }

  fs.writeFileSync(frontEndContractFile, JSON.stringify(contractAddresses));
}

module.exports.tags = ["all", "frontend"];
