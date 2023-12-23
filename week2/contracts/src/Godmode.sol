// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC777} from "./lib/ERC777.sol";

/// @title An ERC777 token with a godmode
/// @author Gustavo Konrad
/// @dev Contract owner is defined as an irrevokable default operator for every user.
///      By virtue of being a default operator, they can mint, send and burn tokens on every
///      user's behalf.
contract GodmodeToken is ERC777 {
    /// @notice Address of the contract owner.
    address public owner;

    /// @notice Emitted when ownership is transferred to a new address.
    event OwnershipTransferred(address indexed newOwner);

    /// @dev Initializes the contract, setting the initial owner and default operator.
    /// @param name_ Name of the token.
    /// @param symbol_ Symbol of the token.
    constructor(string memory name_, string memory symbol_) ERC777(name_, symbol_, 0) {
        owner = msg.sender;
        address[] memory _defaultOperators = new address[](1);
        _defaultOperators[0] = owner;
        _setDefaultOperators(_defaultOperators);
    }

    /// @dev Ensures that only the contract owner can call a function.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can run this function.");
        _;
    }

    /// @notice Transfers ownership of the contract to a new address.
    /// @dev Can only be called by the current owner.
    /// @param owner_ The address of the new owner.
    function setOwner(address owner_) public virtual onlyOwner {
        owner = owner_;
        address[] memory _defaultOperators = new address[](1);
        _defaultOperators[0] = owner;
        _setDefaultOperators(_defaultOperators);
        emit OwnershipTransferred(owner);
    }

    /// @notice Mints new tokens and assigns them to a specified account.
    /// @dev Can be called by anyone, leveraging the owner's default operator status.
    /// @param account The account to which the tokens will be minted.
    /// @param amount The amount of tokens to mint.
    /// @param userData Additional information provided by the token holder (if any).
    /// @param operatorData Additional information provided by the operator (if any).
    function mint(address account, uint256 amount, bytes memory userData, bytes memory operatorData) public virtual {
        _mint(account, amount, userData, operatorData, false);
    }

    /// @notice Revokes a specified operator for the caller.
    /// @dev The owner cannot be revoked as an operator.
    /// @param operator The operator to revoke.
    function revokeOperator(address operator) public virtual override {
        require(operator != owner, "Contract owner is always an operator.");
        _revokeOperator(operator);
    }
}
