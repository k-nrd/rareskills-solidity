// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC777} from "./lib/ERC777.sol";

/// @title SanctionedToken
/// @author Gustavo Konrad
/// @dev An ERC777 token with a banlist feature, allowing the contract owner to ban and unban addresses.
///      Banned addresses are restricted from sending, receiving, burning, or minting tokens.
///      Banned addresses are also restricted from operating on behalf of other addresses.
///      Banlists are controlled by the contract's owner.
contract SanctionedToken is ERC777 {
    /// @dev Mapping of addresses to their ban status.
    mapping(address => bool) public banlist;

    /// @dev Address of the contract owner.
    address owner;

    /// @notice Emitted when an address is banned.
    event Banned(address indexed target);

    /// @notice Emitted when an address is unbanned.
    event Unbanned(address indexed target);

    /// @notice Emitted when ownership is transferred to a new address.
    event OwnershipTransferred(address indexed newOwner);

    /// @dev Sets the token name, symbol, and assigns the contract creator as the owner.
    /// @param name_ Name of the token.
    /// @param symbol_ Symbol of the token.
    /// @param totalSupply_ How many tokens to mint for the owner on deploy.
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_) ERC777(name_, symbol_, 0) {
        // This only makes sense if we plan on changing it later, else it's unnecessary storage use
        owner = msg.sender;
        _mint(owner, totalSupply_, "", "", false);
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
        emit OwnershipTransferred(owner);
    }

    /// @notice Bans an address, preventing it from sending, receiving, burning, or minting tokens.
    /// @dev Can only be called by the contract owner.
    /// @param _target The address to be banned.
    function ban(address _target) external virtual onlyOwner {
        require(!banlist[_target], "Target is already banned.");
        banlist[_target] = true;
        emit Banned(_target);
    }

    /// @notice Unbans an address, allowing it to send, receive, burn, or mint tokens again.
    /// @dev Can only be called by the contract owner.
    /// @param _target The address to be unbanned.
    function unban(address _target) external virtual onlyOwner {
        require(banlist[_target], "Target is already unbanned.");
        banlist[_target] = false;
        emit Unbanned(_target);
    }

    /// @notice Send an amount of tokens to a specified address.
    /// @dev Overrides ERC777 send function with banlist check.
    /// @param to The recipient's address.
    /// @param amount The amount of tokens to send.
    /// @param userData Additional data to send with the transfer.
    function send(address to, uint256 amount, bytes calldata userData) public virtual override {
        require(!banlist[msg.sender], "Banned users cannot send tokens.");
        require(!banlist[to], "Banned users cannot receive tokens.");
        _send(msg.sender, to, amount, userData, "", true);
    }

    /// @notice Allows an operator to send tokens on behalf of another address.
    /// @dev Overrides ERC777 operatorSend function with banlist check.
    /// @param from The address whose tokens are being sent.
    /// @param to The recipient's address.
    /// @param amount The amount of tokens to send.
    /// @param userData Additional data to send with the transfer.
    /// @param operatorData Additional data about the operator.
    function operatorSend(
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) public virtual override {
        require(!banlist[msg.sender], "Banned users cannot act as operators.");
        require(!banlist[from], "Operators can't send tokens on behalf of banned users.");
        require(!banlist[to], "Operators can't send tokens to banned users.");
        require(isOperatorFor(msg.sender, from), "Address is not an operator for holder.");
        _send(from, to, amount, userData, operatorData, true);
    }

    /// @notice Burn an amount of the caller's tokens.
    /// @dev Overrides ERC777 burn function with banlist check.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data associated with the burn.
    function burn(uint256 amount, bytes calldata userData) public virtual override {
        require(!banlist[msg.sender], "Banned users cannot burn tokens.");
        _burn(msg.sender, amount, userData, "");
    }

    /// @notice Allows an operator to burn tokens on behalf of another address.
    /// @dev Overrides ERC777 operatorBurn function with banlist check.
    /// @param from The address whose tokens are being burned.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data associated with the burn.
    /// @param operatorData Additional data about the operator.
    function operatorBurn(address from, uint256 amount, bytes calldata userData, bytes calldata operatorData)
        public
        virtual
        override
    {
        require(!banlist[msg.sender], "Banned users cannot act as operators.");
        require(!banlist[from], "Operators can't burn tokens on behalf of banned users.");
        require(isOperatorFor(msg.sender, from), "Address if not an operator for holder.");
        _burn(from, amount, userData, operatorData);
    }

    /// @notice Mint new tokens to a specified address.
    /// @param account The address to which the tokens will be minted.
    /// @param amount The amount of tokens to mint.
    /// @param userData Additional information provided by the token holder (if any).
    /// @param operatorData Additional information provided by the operator (if any).
    function mint(address account, uint256 amount, bytes memory userData, bytes memory operatorData) public virtual {
        require(!banlist[msg.sender], "Banned users cannot mint tokens.");
        require(!banlist[account], "Cannot mint tokens on behalf of banned users.");
        _mint(account, amount, userData, operatorData, true);
    }
}
