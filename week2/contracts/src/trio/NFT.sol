// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

contract NFT is ERC721 {
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public _tokenId = 0;

    constructor() ERC721("CryptoHippos", "CHPS") {}

    function mint(address to) external {
        require(_tokenId < MAX_SUPPLY, "Max supply reached");
        _safeMint(to, _tokenId);
        _tokenId++;
    }
}
