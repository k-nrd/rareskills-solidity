// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title ENFT (Enumerable NFT)
/// @notice This contract implements an enumerable NFT with a capped supply.
/// @dev Extends ERC721Enumerable to provide an enumerable NFT implementation with a fixed maximum supply.
contract ENFT is ERC721Enumerable {
    /// @dev Maximum number of tokens that can be minted.
    uint256 private constant MAX_SUPPLY = 100;

    /// @dev Current token ID counter, starts at 1.
    uint256 private _tokenId = 1;

    /// @notice Initializes the NFT contract with a name and a symbol, and pre-mints a batch of tokens.
    /// @dev The constructor mints the first 20 tokens to the contract itself.
    /// @param _name The name of the NFT collection.
    /// @param _symbol The symbol of the NFT collection.
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        for (uint256 index = 0; index < 20; index++) {
            _mint(address(this), _tokenId);
            _tokenId++;
        }
    }

    /// @dev Internal function that overrides the _update function from ERC721Enumerable.
    /// This function enforces the maximum supply limit for token minting.
    /// @param to The address receiving the token.
    /// @param tokenId The ID of the token being transferred.
    /// @param auth The address performing the update.
    /// @return The updated address after performing the base logic.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        require(tokenId < MAX_SUPPLY + 1, "Max supply reached");
        return ERC721Enumerable._update(to, tokenId, auth);
    }
}
