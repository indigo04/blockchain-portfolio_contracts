import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("NftFactory (Upgradeable)", function () {
  let nftFactory: any;
  let nftImplementation: any;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    const NftTokenFactory = await ethers.getContractFactory("NftToken");
    nftImplementation = await NftTokenFactory.deploy();
    await nftImplementation.waitForDeployment();

    const NftFactoryFactory = await ethers.getContractFactory("NftFactory");
    nftFactory = await upgrades.deployProxy(
      NftFactoryFactory,
      [owner.address, await nftImplementation.getAddress()],
      {
        initializer: "initialize",
        unsafeAllow: ["constructor"],
      }
    );
    await nftFactory.waitForDeployment();
  });

  describe("Deployment & Initialization", function () {
    it("Should set the correct initial owner", async function () {
      expect(await nftFactory.owner()).to.equal(owner.address);
    });

    it("Should set the correct NFT implementation address", async function () {
      expect(await nftFactory.nftImplementation()).to.equal(
        await nftImplementation.getAddress()
      );
    });

    it("Should fail if trying to initialize again", async function () {
      await expect(
        nftFactory.initialize(user1.address, ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(nftFactory, "InvalidInitialization");
    });
  });

  describe("Collection Creation", function () {
    const name = "CryptoArt";
    const symbol = "CART";

    it("Should successfully create a clone collection and emit event", async function () {
      const tx = await nftFactory.connect(user1).createCollection(name, symbol);
      const receipt = await tx.wait();

      const event = receipt.logs
        .map((log: any) => {
          try {
            return nftFactory.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((parsedLog: any) => parsedLog && parsedLog.name === "CollectionCreated");

      expect(event).to.not.be.undefined;
      const cloneAddress = event.args.collectionAddress;

      expect(event.args.name).to.equal(name);
      expect(event.args.symbol).to.equal(symbol);

      const NftTokenFactory = await ethers.getContractFactory("NftToken");
      const clonedNft = NftTokenFactory.attach(cloneAddress) as any;

      expect(await clonedNft.name()).to.equal(name);
      expect(await clonedNft.symbol()).to.equal(symbol);
      expect(await clonedNft.owner()).to.equal(user1.address);
    });

    it("Should fail to create collection if name is empty", async function () {
      await expect(
        nftFactory.connect(user1).createCollection("", symbol)
      ).to.be.revertedWithCustomError(nftFactory, "InvalidData");
    });

    it("Should fail to create collection if symbol is empty", async function () {
      await expect(
        nftFactory.connect(user1).createCollection(name, "")
      ).to.be.revertedWithCustomError(nftFactory, "InvalidData");
    });
  });

  describe("Tracking Collections", function () {
    it("Should track deployed collections via array and getter", async function () {
      expect(await nftFactory.getCollections()).to.have.lengthOf(0);

      const tx1 = await nftFactory.createCollection("First", "FST");
      await tx1.wait();
      
      const tx2 = await nftFactory.createCollection("Second", "SND");
      await tx2.wait();

      const collections = await nftFactory.getCollections();
      expect(collections).to.have.lengthOf(2);

      expect(await nftFactory.deployedCollections(0)).to.equal(collections[0]);
      expect(await nftFactory.deployedCollections(1)).to.equal(collections[1]);
    });
  });
});