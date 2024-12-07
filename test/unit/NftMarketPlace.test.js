const { network, deployments, getNamedAccounts, ethers } = require("hardhat");
const { assert, expect } = require("chai");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Nft Market Place Tests", () => {
      let nftMarketPlace, basicNft, deployer, player;
      const PRICE = ethers.utils.parseEther("0.1");
      const TOKEN_ID = 0;

      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        // player = (await getNamedAccounts()).player;
        const accounts = await getSigners();
        player = accounts[1];
        await deployments.fixture(["all"]);

        nftMarketPlace = await ethers.getContract("NftMarketPlace");
        basicNft = await ethers.getContract("BasicNft");
        await basicNft.mintNft();
        await basicNft.approve(nftMarketPlace.address, TOKEN_ID);
      });

      it("lists and can be bought", async function () {
        await nftMarketPlace.listItem(basicNft.address, TOKEN_ID, PRICE);
        await nftMarketPlace
          .connect(player)
          .buyItem(basicNft.address, TOKEN_ID);
        const newOwner = basicNft.ownerOf(TOKEN_ID);
        const deployerProceeds = await nftMarketPlace.getProceeds(deployer);
      });
    });
