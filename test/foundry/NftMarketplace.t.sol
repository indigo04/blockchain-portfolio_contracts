// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {NftMarketplace} from "../../contracts/NftMarketplace.sol";
import {WilToken} from "../../contracts/WilToken.sol";
import {NftToken} from "../../contracts/NftToken.sol";
import {MockFalseToken} from "../../contracts/utils/MockErc20.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftMarketplaceTest is Test {
    NftMarketplace public marketplaceImplementation;
    NftMarketplace public marketplace;

    WilToken public tokenImplementation;
    WilToken public paymentToken;

    NftToken public nftImplementation;
    NftToken public nftContract;

    address public owner = address(0x1);
    address public seller = address(0x2);
    address public buyer = address(0x3);

    uint256 public constant INITIAL_PRICE = 100 * 10 ** 18; // 100 WIL
    uint256 public constant NFT_ID = 0;
    string public constant TOKEN_URI = "ipfs://";

    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );
    event NFTSold(
        address indexed buyer,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );
    event ListingCanceled(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    function setUp() public {
        tokenImplementation = new WilToken();
        bytes memory tokenData = abi.encodeWithSelector(
            WilToken.initialize.selector,
            owner
        );
        paymentToken = WilToken(
            address(new ERC1967Proxy(address(tokenImplementation), tokenData))
        );

        nftImplementation = new NftToken();
        bytes memory nftData = abi.encodeWithSelector(
            NftToken.initialize.selector,
            "WhatIsLove NFT",
            "WILNFT",
            owner
        );
        nftContract = NftToken(
            address(new ERC1967Proxy(address(nftImplementation), nftData))
        );

        marketplaceImplementation = new NftMarketplace();
        bytes memory marketData = abi.encodeWithSelector(
            NftMarketplace.initialize.selector,
            owner,
            address(paymentToken)
        );
        marketplace = NftMarketplace(
            address(
                new ERC1967Proxy(address(marketplaceImplementation), marketData)
            )
        );

        vm.prank(owner);
        nftContract.safeMint(seller, TOKEN_URI);

        paymentToken.mint(buyer, 1000 * 10 ** 18);
    }

    function test_InitializationSuccess() public view {
        assertEq(address(marketplace.paymentToken()), address(paymentToken));
        assertEq(marketplace.owner(), owner);
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        marketplace.initialize(owner, address(paymentToken));
    }

    function test_ImplementationCannotBeInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        marketplaceImplementation.initialize(owner, address(paymentToken));
    }

    // ==========================================
    // listNft
    // ==========================================

    function test_ListNftSuccess() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);

        vm.expectEmit(true, true, true, true);
        emit NFTListed(seller, address(nftContract), NFT_ID, INITIAL_PRICE);

        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
        vm.stopPrank();

        (
            address listedSeller,
            address listedNftContract,
            uint256 listedTokenId,
            uint256 listedPrice,
            bool active
        ) = marketplace.listings(address(nftContract), NFT_ID);
        assertEq(listedSeller, seller);
        assertEq(listedNftContract, address(nftContract));
        assertEq(listedTokenId, NFT_ID);
        assertEq(listedPrice, INITIAL_PRICE);
        assertTrue(active);
    }

    function test_RevertWhen_ListNftWithZeroPrice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidPrice()"));
        vm.prank(seller);
        marketplace.listNft(address(nftContract), NFT_ID, 0);
    }

    function test_RevertWhen_ListNftAlreadyListed() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);

        vm.expectRevert(abi.encodeWithSignature("AlreadyListed()"));
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
        vm.stopPrank();
    }

    function test_RevertWhen_ListNftNotOwner() public {
        vm.expectRevert(abi.encodeWithSignature("NotOwner()"));
        vm.prank(buyer);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
    }

    function test_RevertWhen_ListNftNotApproved() public {
        vm.expectRevert(abi.encodeWithSignature("NotApproved()"));
        vm.prank(seller);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
    }

    // ==========================================
    // buyNft
    // ==========================================

    function test_BuyNftSuccess() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(marketplace), INITIAL_PRICE);

        vm.expectEmit(true, true, true, true);
        emit NFTSold(buyer, address(nftContract), NFT_ID, INITIAL_PRICE);

        marketplace.buyNft(address(nftContract), NFT_ID);
        vm.stopPrank();

        assertEq(nftContract.ownerOf(NFT_ID), buyer);
        assertEq(paymentToken.balanceOf(seller), INITIAL_PRICE);

        (, , , , bool active) = marketplace.listings(
            address(nftContract),
            NFT_ID
        );
        assertFalse(active);
    }

    function test_RevertWhen_BuyNftNotActive() public {
        vm.expectRevert(abi.encodeWithSignature("NotActive()"));
        vm.prank(buyer);
        marketplace.buyNft(address(nftContract), NFT_ID);
    }

    function test_RevertWhen_BuyNftTransferFailed() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        nftContract.approve(address(marketplace), NFT_ID);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
        vm.stopPrank();

        MockFalseToken mockToken = new MockFalseToken();

        vm.store(
            address(marketplace),
            bytes32(uint256(0)),
            bytes32(abi.encode(address(mockToken)))
        );

        assertEq(address(marketplace.paymentToken()), address(mockToken));

        vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));

        vm.prank(buyer);
        marketplace.buyNft(address(nftContract), NFT_ID);
    }

    // ==========================================
    // cancelListing
    // ==========================================

    function test_CancelListingSuccess() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);

        vm.expectEmit(true, true, true, false);
        emit ListingCanceled(seller, address(nftContract), NFT_ID);

        marketplace.cancelListing(address(nftContract), NFT_ID);
        vm.stopPrank();

        (, , , , bool active) = marketplace.listings(
            address(nftContract),
            NFT_ID
        );
        assertFalse(active);
    }

    function test_RevertWhen_CancelListingNotSeller() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("NotSeller()"));
        vm.prank(buyer);
        marketplace.cancelListing(address(nftContract), NFT_ID);
    }

    function test_RevertWhen_CancelListingNotActive() public {
        vm.startPrank(seller);
        nftContract.setApprovalForAll(address(marketplace), true);
        marketplace.listNft(address(nftContract), NFT_ID, INITIAL_PRICE);

        marketplace.cancelListing(address(nftContract), NFT_ID);

        vm.expectRevert(abi.encodeWithSignature("NotActive()"));
        marketplace.cancelListing(address(nftContract), NFT_ID);
        vm.stopPrank();
    }
}
