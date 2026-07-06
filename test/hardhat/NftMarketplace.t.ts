import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("NftMarketplace (Upgradeable)", function () {
  let marketplace: any;
  let mockToken: any;
  let mockNft: any;

  let owner: SignerWithAddress;
  let seller: SignerWithAddress;
  let buyer: SignerWithAddress;

  const tokenId = 0n;
  const price = ethers.parseEther("100");
  const tokenURI = "ipfs://";

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    const WilTokenFactory = await ethers.getContractFactory("WilToken");
    mockToken = await upgrades.deployProxy(WilTokenFactory, [owner.address], {
      initializer: "initialize",
      unsafeAllow: ["constructor"],
    });
    await mockToken.waitForDeployment();

    const NftTokenFactory = await ethers.getContractFactory("NftToken");
    mockNft = await upgrades.deployProxy(
      NftTokenFactory,
      ["Test NFT", "TNFT", owner.address],
      {
        initializer: "initialize",
        unsafeAllow: ["constructor"],
      },
    );
    await mockNft.waitForDeployment();

    const NftMarketplaceFactory = await ethers.getContractFactory(
      "NftMarketplace",
    );
    marketplace = await upgrades.deployProxy(
      NftMarketplaceFactory,
      [owner.address, await mockToken.getAddress()],
      {
        initializer: "initialize",
        unsafeAllow: ["constructor"],
      },
    );
    await marketplace.waitForDeployment();

    await mockNft.connect(owner).safeMint(seller.address, tokenURI);
  });

  describe("Deployment & Initialization", function () {
    it("Should set the correct initial owner and payment token", async function () {
      expect(await marketplace.owner()).to.equal(owner.address);
      expect(await marketplace.paymentToken()).to.equal(
        await mockToken.getAddress(),
      );
    });

    it("Should fail if trying to initialize again", async function () {
      await expect(
        marketplace.initialize(owner.address, ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(marketplace, "InvalidInitialization");
    });
  });

  describe("Listing (listNft)", function () {
    it("Should fail if price is zero", async function () {
      await expect(
        marketplace
          .connect(seller)
          .listNft(await mockNft.getAddress(), tokenId, 0),
      ).to.be.revertedWithCustomError(marketplace, "InvalidPrice");
    });

    it("Should fail if caller is not the owner of the NFT", async function () {
      await expect(
        marketplace
          .connect(buyer)
          .listNft(await mockNft.getAddress(), tokenId, price),
      ).to.be.revertedWithCustomError(marketplace, "NotOwner");
    });

    it("Should fail if marketplace is not approved for all", async function () {
      await expect(
        marketplace
          .connect(seller)
          .listNft(await mockNft.getAddress(), tokenId, price),
      ).to.be.revertedWithCustomError(marketplace, "NotApproved");
    });

    it("Should successfully list NFT and emit event", async function () {
      await mockNft
        .connect(seller)
        .setApprovalForAll(await marketplace.getAddress(), true);

      await expect(
        marketplace
          .connect(seller)
          .listNft(await mockNft.getAddress(), tokenId, price),
      )
        .to.emit(marketplace, "NFTListed")
        .withArgs(seller.address, await mockNft.getAddress(), tokenId, price);

      const listing = await marketplace.listings(
        await mockNft.getAddress(),
        tokenId,
      );
      expect(listing.seller).to.equal(seller.address);
      expect(listing.nftContract).to.equal(await mockNft.getAddress());
      expect(listing.tokenId).to.equal(tokenId);
      expect(listing.price).to.equal(price);
      expect(listing.active).to.be.true;
    });

    it("Should fail if NFT is already listed", async function () {
      await mockNft
        .connect(seller)
        .setApprovalForAll(await marketplace.getAddress(), true);
      await marketplace
        .connect(seller)
        .listNft(await mockNft.getAddress(), tokenId, price);

      await expect(
        marketplace
          .connect(seller)
          .listNft(await mockNft.getAddress(), tokenId, price),
      ).to.be.revertedWithCustomError(marketplace, "AlreadyListed");
    });
  });

  describe("Buying (buyNft)", function () {
    beforeEach(async function () {
      await mockNft
        .connect(seller)
        .setApprovalForAll(await marketplace.getAddress(), true);
      await marketplace
        .connect(seller)
        .listNft(await mockNft.getAddress(), tokenId, price);
    });

    it("Should fail if listing is not active", async function () {
      await mockToken.connect(owner).mint(buyer.address, price);
      await mockToken
        .connect(buyer)
        .approve(await marketplace.getAddress(), price);
      await marketplace
        .connect(buyer)
        .buyNft(await mockNft.getAddress(), tokenId);

      await expect(
        marketplace.connect(buyer).buyNft(await mockNft.getAddress(), tokenId),
      ).to.be.revertedWithCustomError(marketplace, "NotActive");
    });

    it("Should fail with TransferFailed if ERC20 transferFrom returns false", async function () {
      const MockBadTokenFactory = await ethers.getContractFactory(
        "MockFalseToken",
      );
      const badToken = await upgrades.deployProxy(MockBadTokenFactory, []);
      await badToken.waitForDeployment();

      const NftMarketplaceFactory = await ethers.getContractFactory(
        "NftMarketplace",
      );
      const badMarketplace = await upgrades.deployProxy(
        NftMarketplaceFactory,
        [owner.address, await badToken.getAddress()],
        {
          initializer: "initialize",
          unsafeAllow: ["constructor"],
        },
      );
      await badMarketplace.waitForDeployment();

      await mockNft
        .connect(seller)
        .setApprovalForAll(await badMarketplace.getAddress(), true);
      await badMarketplace
        .connect(seller)
        .listNft(await mockNft.getAddress(), tokenId, price);

      await expect(
        badMarketplace
          .connect(buyer)
          .buyNft(await mockNft.getAddress(), tokenId),
      ).to.be.revertedWithCustomError(badMarketplace, "TransferFailed");
    });

    it("Should fail with ReentrancyGuardReentrantCall error during attack", async function () {
      const ReentrancyAttackerFactory = await ethers.getContractFactory(
        "ReentrancyAttacker",
      );
      const attacker = await ReentrancyAttackerFactory.deploy(
        await marketplace.getAddress(),
        await mockNft.getAddress(),
        tokenId,
        await mockToken.getAddress(),
      );
      await attacker.waitForDeployment();

      await mockToken.connect(owner).mint(await attacker.getAddress(), price);

      await expect(attacker.launchAttack()).to.be.revertedWithCustomError(
        marketplace,
        "ReentrancyGuardReentrantCall",
      );
    });

    it("Should successfully purchase NFT, transfer funds and tokens", async function () {
      await mockToken.connect(owner).mint(buyer.address, price);
      await mockToken
        .connect(buyer)
        .approve(await marketplace.getAddress(), price);

      const initialSellerBalance = await mockToken.balanceOf(seller.address);

      await expect(
        marketplace.connect(buyer).buyNft(await mockNft.getAddress(), tokenId),
      )
        .to.emit(marketplace, "NFTSold")
        .withArgs(buyer.address, await mockNft.getAddress(), tokenId, price);

      expect(await mockToken.balanceOf(seller.address)).to.equal(
        initialSellerBalance + price,
      );

      expect(await mockNft.ownerOf(tokenId)).to.equal(buyer.address);

      const listing = await marketplace.listings(
        await mockNft.getAddress(),
        tokenId,
      );
      expect(listing.active).to.be.false;
    });
  });

  describe("Canceling (cancelListing)", function () {
    beforeEach(async function () {
      await mockNft
        .connect(seller)
        .setApprovalForAll(await marketplace.getAddress(), true);
      await marketplace
        .connect(seller)
        .listNft(await mockNft.getAddress(), tokenId, price);
    });

    it("Should fail if caller is not the seller", async function () {
      await expect(
        marketplace
          .connect(buyer)
          .cancelListing(await mockNft.getAddress(), tokenId),
      ).to.be.revertedWithCustomError(marketplace, "NotSeller");
    });

    it("Should successfully cancel listing and emit event", async function () {
      await expect(
        marketplace
          .connect(seller)
          .cancelListing(await mockNft.getAddress(), tokenId),
      )
        .to.emit(marketplace, "ListingCanceled")
        .withArgs(seller.address, await mockNft.getAddress(), tokenId);

      const listing = await marketplace.listings(
        await mockNft.getAddress(),
        tokenId,
      );
      expect(listing.active).to.be.false;
    });

    it("Should fail if trying to cancel an already inactive listing", async function () {
      await marketplace
        .connect(seller)
        .cancelListing(await mockNft.getAddress(), tokenId);

      await expect(
        marketplace
          .connect(seller)
          .cancelListing(await mockNft.getAddress(), tokenId),
      ).to.be.revertedWithCustomError(marketplace, "NotActive");
    });
  });
});
