// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20Private} from "../lib/ERC20Private.sol";

/// @title NFTShare
/// @notice This contract represents a share token for the CryptoHippos ecosystem.
/// @dev Extends the ERC20Private contract to implement a share token with minting and burning functionality.
contract NFTShare is ERC20Private {
    /// @notice Initializes the NFTShare contract with a predefined name and symbol, assigning the vault as the owner.
    /// @dev Creates an ERC20 token named "CryptoHipposShare" with the symbol "CHPS", and assigns the provided vault address as the owner.
    /// @param _vault The address of the vault which will own and control the minting and burning of these share tokens.
    constructor(address _vault) ERC20Private("CryptoHipposShare", "CHPS", _vault) {}
}
