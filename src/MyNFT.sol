// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title A mock NFT contract

contract MyNFT is ERC721 {
    constructor() ERC721("MyNFT", "MTK") {}

    function safeMint(address to, uint256 tokenId) public  {
        _safeMint(to, tokenId);
    }
}