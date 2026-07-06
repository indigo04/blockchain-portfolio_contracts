import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("NftToken (Upgradeable)", function () {
  let nftToken: any;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;

  const collectionName = "MyCollection";
  const collectionSymbol = "NFT";
  const tokenURI = "ipfs://QmTTokenUri123";
  const alternativeURI = "ipfs://QmAnotherUri456";

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const NftTokenFactory = await ethers.getContractFactory("NftToken");

    nftToken = await upgrades.deployProxy(
      NftTokenFactory,
      [collectionName, collectionSymbol, owner.address],
      {
        initializer: "initialize",
        unsafeAllow: ["constructor"],
      },
    );
    await nftToken.waitForDeployment();
  });

  describe("Deployment & Initialization", function () {
    it("Should set the correct collection name and symbol", async function () {
      expect(await nftToken.name()).to.equal(collectionName);
      expect(await nftToken.symbol()).to.equal(collectionSymbol);
    });

    it("Should set the correct initial owner", async function () {
      expect(await nftToken.owner()).to.equal(owner.address);
    });

    it("Should fail if trying to initialize again", async function () {
      await expect(
        nftToken.initialize("NewName", "NWN", user1.address),
      ).to.be.revertedWithCustomError(nftToken, "InvalidInitialization");
    });
  });

  describe("Minting & Metadata (safeMint)", function () {
    it("Should allow the owner to safely mint NFTs, increment token IDs, and set URIs", async function () {
      const firstTokenId = 0n;
      const secondTokenId = 1n;

      await expect(nftToken.connect(owner).safeMint(user1.address, tokenURI))
        .to.emit(nftToken, "Transfer")
        .withArgs(ethers.ZeroAddress, user1.address, firstTokenId);

      expect(await nftToken.ownerOf(firstTokenId)).to.equal(user1.address);
      expect(await nftToken.balanceOf(user1.address)).to.equal(1n);
      expect(await nftToken.tokenURI(firstTokenId)).to.equal(tokenURI);

      await expect(
        nftToken.connect(owner).safeMint(user2.address, alternativeURI),
      )
        .to.emit(nftToken, "Transfer")
        .withArgs(ethers.ZeroAddress, user2.address, secondTokenId);

      expect(await nftToken.ownerOf(secondTokenId)).to.equal(user2.address);
      expect(await nftToken.tokenURI(secondTokenId)).to.equal(alternativeURI);
    });

    it("Should fail if a non-owner tries to mint an NFT", async function () {
      await expect(nftToken.connect(user1).safeMint(user1.address, tokenURI))
        .to.be.revertedWithCustomError(nftToken, "OwnableUnauthorizedAccount")
        .withArgs(user1.address);
    });

    it("Should allow minting with an empty URI string", async function () {
      const tokenId = 0n;
      await nftToken.connect(owner).safeMint(user1.address, "");

      expect(await nftToken.tokenURI(tokenId)).to.equal("");
    });

    it("Should fail to get URI for a non-existent token", async function () {
      const nonExistentId = 999n;
      await expect(nftToken.tokenURI(nonExistentId))
        .to.be.revertedWithCustomError(nftToken, "ERC721NonexistentToken")
        .withArgs(nonExistentId);
    });
  });

  describe("ERC721 Transfers & Approvals", function () {
    const tokenId = 0n;

    beforeEach(async function () {
      await nftToken.connect(owner).safeMint(user1.address, tokenURI);
    });

    it("Should allow owner of the token to transfer it", async function () {
      await expect(
        nftToken
          .connect(user1)
          .transferFrom(user1.address, user2.address, tokenId),
      )
        .to.emit(nftToken, "Transfer")
        .withArgs(user1.address, user2.address, tokenId);

      expect(await nftToken.ownerOf(tokenId)).to.equal(user2.address);
      expect(await nftToken.balanceOf(user1.address)).to.equal(0n);
      expect(await nftToken.balanceOf(user2.address)).to.equal(1n);
    });

    it("Should allow approved address to transfer the token", async function () {
      await expect(nftToken.connect(user1).approve(user2.address, tokenId))
        .to.emit(nftToken, "Approval")
        .withArgs(user1.address, user2.address, tokenId);

      expect(await nftToken.getApproved(tokenId)).to.equal(user2.address);

      await nftToken
        .connect(user2)
        .transferFrom(user1.address, user2.address, tokenId);
      expect(await nftToken.ownerOf(tokenId)).to.equal(user2.address);

      expect(await nftToken.getApproved(tokenId)).to.equal(ethers.ZeroAddress);
    });

    it("Should allow operator (ApprovalForAll) to transfer tokens", async function () {
      await expect(
        nftToken.connect(user1).setApprovalForAll(user2.address, true),
      )
        .to.emit(nftToken, "ApprovalForAll")
        .withArgs(user1.address, user2.address, true);

      expect(await nftToken.isApprovedForAll(user1.address, user2.address)).to
        .be.true;

      await nftToken
        .connect(user2)
        .transferFrom(user1.address, user2.address, tokenId);
      expect(await nftToken.ownerOf(tokenId)).to.equal(user2.address);
    });

    it("Should fail to transfer if not approved or owner", async function () {
      await expect(
        nftToken
          .connect(user2)
          .transferFrom(user1.address, user2.address, tokenId),
      )
        .to.be.revertedWithCustomError(nftToken, "ERC721InsufficientApproval")
        .withArgs(user2.address, tokenId);
    });
  });

  describe("ERC165 Interface Support", function () {
    it("Should support standard interfaces", async function () {
      const INTERFACE_IDS = {
        erc165: "0x01ffc9a7",
        erc721: "0x80ac58cd",
        erc721Metadata: "0x5b5e139f",
        invalid: "0xffffffff",
      };

      expect(await nftToken.supportsInterface(INTERFACE_IDS.erc165)).to.be.true;
      expect(await nftToken.supportsInterface(INTERFACE_IDS.erc721)).to.be.true;
      expect(await nftToken.supportsInterface(INTERFACE_IDS.erc721Metadata)).to
        .be.true;
      expect(await nftToken.supportsInterface(INTERFACE_IDS.invalid)).to.be
        .false;
    });
  });
});
