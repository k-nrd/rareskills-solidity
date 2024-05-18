// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "openzeppelin/utils/math/Math.sol";
import {ERC721Enumerable} from "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import {PrimeSearch} from "../lib/PrimeSearch.sol";

/// @title Prime Count
/// @notice This contract provides functionality to count the number of NFTs owned by an address with prime number token IDs.
/// @dev Utilizes the PrimeSearch library to determine if token IDs are prime numbers.
contract PrimeCount {
    using Math for *;
    using PrimeSearch for *;

    /// @dev Reference to the ERC721Enumerable contract whose tokens are being analyzed.
    ERC721Enumerable private _enumerableNft;

    /// @dev Mapping to track if a number is a prime basis.
    mapping(uint256 => bool) private _primeBasis;

    /// @notice Initializes the contract with a reference to an ERC721Enumerable contract.
    /// @dev Sets the `_enumerableNft` to the provided enumerable NFT contract.
    /// @param enumerableNft The ERC721Enumerable contract to interact with.
    constructor(ERC721Enumerable enumerableNft) {
        _enumerableNft = enumerableNft;
    }

    /// @notice Counts the number of NFTs owned by an address that have prime number token IDs.
    /// @dev Iterates through the tokens owned by the holder and checks if their token IDs are prime.
    /// @param holder The address whose NFTs are to be analyzed.
    /// @return primeCount The number of NFTs with prime number token IDs owned by the holder.
    function getPrimeNFTCount(address holder) public view returns (uint256) {
        uint256 tokenCount = _enumerableNft.balanceOf(holder);
        uint256 primeCount = 0;
        for (uint256 index = 0; index < tokenCount; index++) {
            uint256 tokenId = _enumerableNft.tokenOfOwnerByIndex(holder, index);
            if (PrimeSearch.isPrime(tokenId)) {
                primeCount++;
            }
        }
        return primeCount;
    }
}
