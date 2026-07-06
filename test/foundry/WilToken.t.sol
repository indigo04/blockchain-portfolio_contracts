// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WilToken} from "../../contracts/WilToken.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WilTokenTest is Test {
    WilToken public implementation;
    WilToken public token;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    function setUp() public {
        implementation = new WilToken();

        bytes memory data = abi.encodeWithSelector(
            WilToken.initialize.selector,
            owner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        token = WilToken(address(proxy));
    }

    // ==========================================
    // (Initialization)
    // ==========================================

    function test_InitializationSuccess() public view {
        assertEq(token.name(), "WhatIsLove");
        assertEq(token.symbol(), "WIL");
        assertEq(token.owner(), owner);
        assertEq(token.decimals(), 18);
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        token.initialize(user1);
    }

    function test_ImplementationCannotBeInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        implementation.initialize(owner);
    }

    // ==========================================
    // mint (Minting)
    // ==========================================

    function test_PublicMintSuccessForAnyUser() public {
        uint256 mintAmount1 = 500 * 10 ** 18;
        uint256 mintAmount2 = 1200 * 10 ** 18;

        vm.prank(user1);
        token.mint(user1, mintAmount1);
        assertEq(token.balanceOf(user1), mintAmount1);

        vm.prank(user2);
        token.mint(user2, mintAmount2);
        assertEq(token.balanceOf(user2), mintAmount2);

        assertEq(token.totalSupply(), mintAmount1 + mintAmount2);
    }
}
