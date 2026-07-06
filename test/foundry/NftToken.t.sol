// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {NftToken} from "../../contracts/NftToken.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NftTokenTest is Test {
    NftToken public implementation;
    NftToken public token;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    string public constant NAME = "TestCollection";
    string public constant SYMBOL = "TC";
    string public constant TOKEN_URI = "ipfs://QmTTokenUri123";
    string public constant ALTERNATIVE_URI = "ipfs://QmAnotherUri456";

    function setUp() public {
        implementation = new NftToken();

        bytes memory data = abi.encodeWithSelector(
            NftToken.initialize.selector,
            NAME,
            SYMBOL,
            owner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        token = NftToken(address(proxy));
    }

    // ==========================================
    // (Initialization)
    // ==========================================

    function test_InitializationSuccess() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.owner(), owner);
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        token.initialize("NewName", "NW", user1);
    }

    function test_ImplementationCannotBeInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        implementation.initialize(NAME, SYMBOL, owner);
    }

    // ==========================================
    // safeMint (Minting & Metadata)
    // ==========================================

    function test_SafeMintSuccessByOwner() public {
        vm.prank(owner);
        uint256 tokenId0 = token.safeMint(user1, TOKEN_URI);

        assertEq(tokenId0, 0);
        assertEq(token.ownerOf(0), user1);
        assertEq(token.balanceOf(user1), 1);
        assertEq(token.tokenURI(0), TOKEN_URI);

        vm.prank(owner);
        uint256 tokenId1 = token.safeMint(user2, ALTERNATIVE_URI);

        assertEq(tokenId1, 1);
        assertEq(token.ownerOf(1), user2);
        assertEq(token.balanceOf(user2), 1);
        assertEq(token.tokenURI(1), ALTERNATIVE_URI);
    }

    function test_CannotSafeMintByNonOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );

        vm.prank(user1);
        token.safeMint(user1, TOKEN_URI);
    }

    function test_SafeMintWithEmptyUri() public {
        vm.prank(owner);
        uint256 tokenId = token.safeMint(user1, "");

        assertEq(tokenId, 0);
        assertEq(token.tokenURI(0), "");
    }

    function test_CannotGetUriForNonExistentToken() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999)
        );
        token.tokenURI(999);
    }

    // ==========================================
    // ERC721 Transfers & Approvals
    // ==========================================

    function test_TransferSuccess() public {
        vm.prank(owner);
        uint256 tokenId = token.safeMint(user1, TOKEN_URI);

        vm.prank(user1);
        token.transferFrom(user1, user2, tokenId);

        assertEq(token.ownerOf(tokenId), user2);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 1);
    }

    function test_ApprovedTransferSuccess() public {
        vm.prank(owner);
        uint256 tokenId = token.safeMint(user1, TOKEN_URI);

        vm.prank(user1);
        token.approve(user2, tokenId);

        assertEq(token.getApproved(tokenId), user2);

        vm.prank(user2);
        token.transferFrom(user1, user2, tokenId);

        assertEq(token.ownerOf(tokenId), user2);

        assertEq(token.getApproved(tokenId), address(0));
    }

    function test_ApprovalForAllSuccess() public {
        vm.prank(owner);
        uint256 tokenId = token.safeMint(user1, TOKEN_URI);

        vm.prank(user1);
        token.setApprovalForAll(user2, true);

        assertTrue(token.isApprovedForAll(user1, user2));

        vm.prank(user2);
        token.transferFrom(user1, user2, tokenId);

        assertEq(token.ownerOf(tokenId), user2);
    }

    function test_CannotTransferWithoutApproval() public {
        vm.prank(owner);
        uint256 tokenId = token.safeMint(user1, TOKEN_URI);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC721InsufficientApproval(address,uint256)",
                user2,
                tokenId
            )
        );

        vm.prank(user2);
        token.transferFrom(user1, user2, tokenId);
    }

    // ==========================================
    // ERC165 supportsInterface
    // ==========================================

    function test_SupportsInterface() public view {
        assertTrue(token.supportsInterface(0x01ffc9a7));

        assertTrue(token.supportsInterface(0x80ac58cd));

        assertTrue(token.supportsInterface(0x5b5e139f));

        assertFalse(token.supportsInterface(0xffffffff));
    }
}
