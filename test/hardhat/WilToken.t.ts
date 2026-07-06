import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("WilToken (Upgradeable)", function () {
  let wilToken: any;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const WilTokenFactory = await ethers.getContractFactory("WilToken");

    wilToken = await upgrades.deployProxy(WilTokenFactory, [owner.address], {
      initializer: "initialize",
      unsafeAllow: ["constructor"],
    });
    await wilToken.waitForDeployment();
  });

  describe("Deployment & Initialization", function () {
    it("Should set the correct token name and symbol", async function () {
      expect(await wilToken.name()).to.equal("WhatIsLove");
      expect(await wilToken.symbol()).to.equal("WIL");
    });

    it("Should set the correct initial owner", async function () {
      expect(await wilToken.owner()).to.equal(owner.address);
    });

    it("Should fail if trying to initialize again", async function () {
      await expect(
        wilToken.initialize(user1.address),
      ).to.be.revertedWithCustomError(wilToken, "InvalidInitialization");
    });
  });

  describe("Minting", function () {
    it("Should allow anyone to mint tokens (згідно з поточним кодом контракту)", async function () {
      const mintAmount = ethers.parseEther("1000");

      await expect(wilToken.connect(owner).mint(user1.address, mintAmount))
        .to.emit(wilToken, "Transfer")
        .withArgs(ethers.ZeroAddress, user1.address, mintAmount);

      expect(await wilToken.balanceOf(user1.address)).to.equal(mintAmount);

      await wilToken.connect(user1).mint(user1.address, mintAmount);
      expect(await wilToken.balanceOf(user1.address)).to.equal(mintAmount * 2n);
    });

    it("Should increase total supply after minting", async function () {
      const mintAmount = ethers.parseEther("500");

      const initialSupply = await wilToken.totalSupply();
      expect(initialSupply).to.equal(0);

      await wilToken.mint(user2.address, mintAmount);

      const finalSupply = await wilToken.totalSupply();
      expect(finalSupply).to.equal(mintAmount);
    });
  });
});
