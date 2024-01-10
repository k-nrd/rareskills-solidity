// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";

/// @title ERC20Private
/// @notice This contract extends the ERC20 standard with minting and burning functionality, controlled by the owner.
/// @dev Inherits from OpenZeppelin's ERC20, Ownable, and Ownable2Step contracts.
contract ERC20Private is ERC20, Ownable2Step {
    /// @notice Initializes the contract, setting the token's name, symbol, and initial minter (owner).
    /// @dev Sets up the ERC20 token with a name and a symbol, and assigns the minter role to the specified address.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param minter The address with the initial minter (owner) role.
    constructor(string memory name, string memory symbol, address minter) ERC20(name, symbol) Ownable(minter) {}

    /// @notice Mints a specified amount of tokens to a given account.
    /// @dev Can only be called by the contract owner.
    /// @param account The address that will receive the minted tokens.
    /// @param amount The amount of tokens to be minted.
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    /// @notice Burns a specified amount of tokens from a given account.
    /// @dev Can only be called by the contract owner.
    /// @param account The address from which tokens will be burned.
    /// @param amount The amount of tokens to be burned.
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
