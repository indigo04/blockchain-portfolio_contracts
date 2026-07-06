// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;

contract MockFalseToken {
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        return false;
    }
}
