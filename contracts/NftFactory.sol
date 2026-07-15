// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NftToken} from "./NftToken.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title NFTFactoryUpgradeable
 * @author Vladyslav (indigo04)
 * @notice This contract acts as a factory to deploy and track multiple upgradeable NFT collections.
 * @dev This factory contract itself is upgradeable and utilizes the OpenZeppelin initializable pattern.
 * It deploys instances of the `NftToken` contract and initializes them on the fly.
 */
contract NftFactory is Initializable, OwnableUpgradeable {
    /// @notice The address of the NFT clones implementation.
    address public nftImplementation;

    /**
     * @notice Array containing the addresses of all NFT collections deployed by this factory.
     * @dev Public getter `deployedCollections(uint256)` is automatically generated to fetch individual addresses.
     */
    address[] public deployedCollections;

    /**
     * @notice Emitted when a new NFT collection is successfully created.
     * @param collectionAddress The smart contract address of the newly deployed NFT collection.
     * @param creator The wallet address of the user who creates NFT collection.
     * @param name The name of the created NFT collection.
     * @param symbol The symbol of the created NFT collection.
     */
    event CollectionCreated(
        address indexed collectionAddress,
        address indexed creator,
        string name,
        string symbol
    );

    /**
     * @notice Reverted when the provided metadata for the collection creation is empty or invalid.
     * @dev Triggered if either the `name` or `symbol` string has a length of 0.
     */
    error InvalidData();

    /// @custom:oz-upgrades-unsafe-allow constructor
    /**
     * @notice Constructor for the implementation contract.
     * @dev Disables initializers to lock the implementation contract, forcing state to be handled via proxies.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory contract and sets the initial owner.
     * @dev Replaces the standard constructor for compatibility with upgradeable proxies.
     * @param initialOwner The address that will be granted ownership of the factory.
     * @param _nftImplementation The address of NFT implementation.
     */
    function initialize(
        address initialOwner,
        address _nftImplementation
    ) public initializer {
        __Ownable_init(initialOwner);
        nftImplementation = _nftImplementation;
    }

    /**
     * @notice Deploys a new custom NFT collection (`NftToken`) and initializes it.
     * @dev Validates input lengths, deploys a new `NftToken` instance using the `new` keyword,
     * transfers its ownership to the caller (`msg.sender`), and records the deployment.
     * @param name The desired name for the new NFT collection.
     * @param symbol The desired symbol for the new NFT collection.
     * @return The address of the newly created NFT collection contract.
     */
    function createCollection(
        string memory name,
        string memory symbol
    ) external returns (address) {
        if (bytes(name).length == 0 || bytes(symbol).length == 0)
            revert InvalidData();

        address clone = Clones.clone(nftImplementation);
        NftToken newCollection = NftToken(clone);

        newCollection.initialize(name, symbol, msg.sender);

        deployedCollections.push(address(newCollection));

        emit CollectionCreated(
            address(newCollection),
            msg.sender,
            name,
            symbol
        );
        return address(newCollection);
    }

    /**
     * @notice Retrieves the full list of all deployed NFT collection addresses.
     * @dev Useful for external front-end integrations to fetch all collections in a single call.
     * @return An array of addresses representing all deployed NFT collections.
     */
    function getCollections() external view returns (address[] memory) {
        return deployedCollections;
    }
}
