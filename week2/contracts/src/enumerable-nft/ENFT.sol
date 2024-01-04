// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

contract ENFT is ERC721Enumerable {
    uint256 private tokenId;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        for (uint256 index = 0; index < 20; index++) {
            _mint(address(this), tokenId);
            tokenId++;
        }
    }
}
