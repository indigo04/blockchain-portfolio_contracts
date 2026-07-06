// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ERC721URIStorageUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

/**
 * @title NftToken
 * @author Vladyslav (indigo04)
 * @notice This contract implements an upgradeable ERC721 Non-Fungible Token (NFT) standard.
 * @dev Designed to be deployed via a Factory pattern using OpenZeppelin upgradeable proxies.
 * State initialization is handled by the `initialize` function instead of a constructor.
 */
contract NftToken is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ERC721URIStorageUpgradeable
{
    /// @dev Internal counter to keep track of the next unique token ID to be minted.
    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    /**
     * @notice Constructor for the implementation contract.
     * @dev Disables initializers to prevent the implementation contract from being initialized directly.
     * The actual state will reside and be initialized within the proxy contracts.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the NFT collection contract with a name, symbol, and initial owner.
     * @dev Replaces the standard constructor for compatibility with upgradeable proxies.
     * Can only be called once per proxy instance.
     * @param name The name of the NFT collection.
     * @param symbol The shorthand symbol of the NFT collection.
     * @param initialOwner The address that will be granted ownership of this collection instance.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address initialOwner
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(initialOwner);
        __ERC721URIStorage_init();
    }

    /**
     * @notice Safely mints a new unique NFT to the specified address.
     * @dev Increments the internal `_nextTokenId` after each successful mint.
     * Restricted to the contract owner via the `onlyOwner` modifier.
     * @param to The recipient wallet address that will receive the minted NFT.
     * @param uri link for the token metadata stored on IPFS.
     * @return The unique token ID of the newly minted NFT.
     */
    function safeMint(
        address to,
        string memory uri
    ) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        _safeMint(to, tokenId);

        if (bytes(uri).length > 0) {
            _setTokenURI(tokenId, uri);
        }

        return tokenId;
    }

    /**
     * @dev Necessary override because the function exists in both ERC721 and URIStorage.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Necessary override for correct operation of interfaces
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
