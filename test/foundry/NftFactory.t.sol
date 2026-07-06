// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, Vm} from "forge-std/Test.sol";
import {NftFactory} from "../../contracts/NftFactory.sol";
import {NftToken} from "../../contracts/NftToken.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftFactoryTest is Test {
    NftFactory public implementation;
    NftFactory public factory;

    address public owner = address(0x1);
    address public user = address(0x2);

    string public constant NAME = "Factory NFT";
    string public constant SYMBOL = "FNFT";

    event CollectionCreated(
        address indexed collectionAddress,
        string name,
        string symbol
    );

    function setUp() public {
        address nftImpl = address(new NftToken());

        implementation = new NftFactory();

        bytes memory data = abi.encodeWithSelector(
            NftFactory.initialize.selector,
            owner,
            nftImpl
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        factory = NftFactory(address(proxy));
    }

    // ==========================================
    // (Initialization)
    // ==========================================

    function test_InitializationSuccess() public view {
        assertEq(factory.owner(), owner);
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        factory.initialize(user, address(0));
    }

    function test_ImplementationCannotBeInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        implementation.initialize(owner, address(0));
    }

    // ==========================================
    // createCollection & getCollections
    // ==========================================

    function test_CreateCollectionSuccess() public {
        vm.recordLogs();

        vm.prank(user);
        address deployedAddress = factory.createCollection(NAME, SYMBOL);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool foundOurEvent = false;
        bytes32 eventSignature = keccak256(
            "CollectionCreated(address,string,string)"
        );

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                foundOurEvent = true;

                address emitedAddress = abi.decode(
                    abi.encodePacked(logs[i].topics[1]),
                    (address)
                );
                assertEq(emitedAddress, deployedAddress);

                (string memory emitedName, string memory emitedSymbol) = abi
                    .decode(logs[i].data, (string, string));
                assertEq(emitedName, NAME);
                assertEq(emitedSymbol, SYMBOL);
                break;
            }
        }

        assertTrue(foundOurEvent, "CollectionCreated event not found");

        assertTrue(deployedAddress != address(0));
        assertEq(factory.deployedCollections(0), deployedAddress);

        address[] memory allCollections = factory.getCollections();
        assertEq(allCollections.length, 1);
        assertEq(allCollections[0], deployedAddress);

        NftToken deployedNft = NftToken(deployedAddress);
        assertEq(deployedNft.name(), NAME);
        assertEq(deployedNft.symbol(), SYMBOL);
        assertEq(deployedNft.owner(), user);
    }

    function test_RevertWhen_NameIsEmpty() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidData()"));

        vm.prank(user);
        factory.createCollection("", SYMBOL);
    }

    function test_RevertWhen_SymbolIsEmpty() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidData()"));

        vm.prank(user);
        factory.createCollection(NAME, "");
    }

    function test_RevertWhen_BothFieldsAreEmpty() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidData()"));

        vm.prank(user);
        factory.createCollection("", "");
    }
}
