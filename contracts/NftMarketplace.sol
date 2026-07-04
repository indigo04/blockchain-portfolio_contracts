// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title NftMarketplace
 * @author Vladyslav (indigo04)
 * @notice This contract facilitates the listing, purchasing, and canceling of NFT sales using a specific ERC20 payment token.
 * @dev This contract is upgradeable using the OpenZeppelin initializable pattern and protects against reentrancy attacks.
 */
contract NftMarketplace is Initializable, OwnableUpgradeable, ReentrancyGuard {
    /**
     * @notice The ERC20 token address accepted as payment for all listings on this marketplace.
     */
    IERC20 public paymentToken;

    /**
     * @notice Struct representing a single NFT sale listing.
     * @param seller The address of the user selling the NFT.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The unique identifier of the token being sold.
     * @param price The amount of `paymentToken` required to purchase the NFT.
     * @param active A boolean flag indicating whether the listing is currently open for purchase.
     */
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    /**
     * @notice Maps an NFT contract address to a specific token ID, which points to its current listing details.
     */
    mapping(address => mapping(uint256 => Listing)) public listings;

    /**
     * @notice Emitted when an NFT is successfully listed for sale.
     * @param seller The address of the user who listed the NFT.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The unique identifier of the listed token.
     * @param price The listing price in the designated ERC20 payment token.
     */
    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );

    /**
     * @notice Emitted when a listed NFT is purchased.
     * @param buyer The address of the user who bought the NFT.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The unique identifier of the purchased token.
     * @param price The sale price paid in the designated ERC20 payment token.
     */
    event NFTSold(
        address indexed buyer,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );

    /**
     * @notice Emitted when a listing is canceled by the seller.
     * @param seller The address of the user who canceled the listing.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The unique identifier of the canceled token listing.
     */
    event ListingCanceled(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    /// @notice Reverted when the caller tries to list already listed NFT.
    error AlreadyListed();

    /// @notice Reverted when the caller is not the owner of the specified NFT.
    error NotOwner();

    /// @notice Reverted when the caller tries to cancel a listing they did not create.
    error NotSeller();

    /// @notice Reverted when the marketplace contract lacks approval to transfer the listed NFT.
    error NotApproved();

    /// @notice Reverted when trying to interact with a listing that is no longer active.
    error NotActive();

    /// @notice Reverted when the specified listing price is zero.
    error InvalidPrice();

    /// @notice Reverted when the ERC20 token transfer from the buyer fails.
    error TransferFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    /**
     * @notice Constructor for the implementation contract.
     * @dev Disables initializers to secure the implementation contract against unauthorized initialization.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the marketplace contract, sets the initial owner and the accepted ERC20 payment token.
     * @dev Replaces the standard constructor for proxy compatibility.
     * @param initialOwner The address granted administrative ownership of the marketplace.
     * @param _paymentToken The address of the ERC20 token used for buying/selling.
     */
    function initialize(
        address initialOwner,
        address _paymentToken
    ) public initializer {
        __Ownable_init(initialOwner);
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @notice Creates a new active listing for an NFT on the marketplace.
     * @dev Validates the price, checks asset ownership, and ensures the marketplace is approved to handle the NFT.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The specific token ID to put up for sale.
     * @param price The listing price (denominated in the payment token's smallest unit/wei).
     */
    function listNft(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external {
        if (price == 0) revert InvalidPrice();
        if (listings[nftContract][tokenId].active) revert AlreadyListed();

        IERC721 nft = IERC721(nftContract);

        if (nft.ownerOf(tokenId) != msg.sender) {
            revert NotOwner();
        }

        if (
            !nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) != address(this)
        ) {
            revert NotApproved();
        }

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit NFTListed(msg.sender, nftContract, tokenId, price);
    }

    /**
     * @notice Purchases an active NFT listing using the marketplace's designated ERC20 payment token.
     * @dev Utilizes `nonReentrant` guard. Transfers ERC20 tokens from buyer to seller,
     * then executes `safeTransferFrom` to move the NFT from seller to buyer.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The specific token ID being purchased.
     */
    function buyNft(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
        Listing storage listing = listings[nftContract][tokenId];

        if (!listing.active) revert NotActive();

        listing.active = false;

        bool success = paymentToken.transferFrom(
            msg.sender,
            listing.seller,
            listing.price
        );

        if (!success) revert TransferFailed();

        IERC721(nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        emit NFTSold(msg.sender, nftContract, tokenId, listing.price);
    }

    /**
     * @notice Cancels an existing active NFT listing, making it unavailable for purchase.
     * @dev Restricted to the original seller of the listing.
     * @param nftContract The address of the ERC721 NFT contract.
     * @param tokenId The specific token ID listing to deactivate.
     */
    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];

        if (listing.seller != msg.sender) revert NotSeller();
        if (!listing.active) revert NotActive();

        listing.active = false;
        emit ListingCanceled(msg.sender, nftContract, tokenId);
    }
}
