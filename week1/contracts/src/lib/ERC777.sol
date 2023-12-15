// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC777Token} from "./ERC777Token.sol";
import {ERC777TokensSender} from "./ERC777TokensSender.sol";
import {ERC777TokensRecipient} from "./ERC777TokensRecipient.sol";
import {IERC1820Registry} from "openzeppelin/interfaces/IERC1820Registry.sol";
import {Address} from "openzeppelin/utils/Address.sol";

/// @title A flexbible implementation of ERC777
/// @author Gustavo Konrad
/// @dev This is based on both the reference implementation and the (now deprecated) OpenZeppelin implementation
contract ERC777 is ERC777Token {
    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    /// @notice The name of the token.
    string private _name;

    /// @notice The symbol of the token.
    string private _symbol;

    /// @notice Total supply of the token.
    uint256 private _totalSupply;

    /// @notice The smallest part into which the token can be divided.
    uint256 private _granularity;

    // @notice Array of addresses that are allowed to manage tokens on behalf of others.
    address[] private _defaultOperatorsArray;

    /// @notice Mapping of address balances.
    mapping(address => uint256) private _balances;

    /// @notice Mapping of addresses to their default operators.
    mapping(address => bool) private _defaultOperators;

    /// @notice Mapping of address pairs to their operator status.
    mapping(address => mapping(address => bool)) private _operators;

    /// @notice Mapping of address pairs to their revoked default operator status.
    mapping(address => mapping(address => bool)) private _revokedDefaultOperators;

    /// @dev Sets the initial values for {_name}, {_symbol} and {_granularity}.
    /// Mints {totalSupply_} tokens for the deployed, setting {_totalSupply} indirectly.
    /// Registers the contract with the ERC1820 registry.
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, uint256 granularity_) {
        _name = name_;
        _symbol = symbol_;
        _granularity = granularity_;
        _totalSupply = totalSupply_;
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
    }

    /// @notice Gets the name of the token.
    /// @return The name of the token.
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @notice Gets the symbol of the token.
    /// @return The symbol of the token.
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /// @notice Gets the total supply of the token.
    /// @return The total supply of the token.
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// @notice Gets the balance of a specific address.
    /// @param holder The address to query the balance of.
    /// @return The amount of tokens owned by the specified address.
    function balanceOf(address holder) public view virtual returns (uint256) {
        return _balances[holder];
    }

    /// @notice Gets the granularity of the token.
    /// @return The smallest part into which the token can be divided.
    function granularity() public view virtual returns (uint256) {
        return _granularity;
    }

    /// @notice Lists all the default operators of the token.
    /// @return An array of addresses that are default operators.
    function defaultOperators() public view virtual returns (address[] memory) {
        return _defaultOperatorsArray;
    }

    /// @notice Checks if an address is an operator for another address.
    /// @param operator The address to check.
    /// @param target The address to check against.
    /// @return True if the `operator` is an operator for `target`, false otherwise.
    function isOperatorFor(address operator, address target) public view virtual returns (bool) {
        return operator == target || (_defaultOperators[operator] && !_revokedDefaultOperators[target][operator])
            || _operators[target][operator];
    }

    /// @notice Authorizes an operator to manage the caller's tokens.
    /// @param operator The address to authorize.
    function authorizeOperator(address operator) public virtual {
        _authorizeOperator(operator);
    }

    /// @notice Revokes an operator's rights to manage the caller's tokens.
    /// @param operator The address to revoke.
    function revokeOperator(address operator) public virtual {
        _revokeOperator(operator);
    }

    /// @notice Sends an amount of tokens to a recipient address.
    /// @param to The recipient's address.
    /// @param amount The amount of tokens to send.
    /// @param userData Additional data to send with the transfer.
    function send(address to, uint256 amount, bytes calldata userData) public virtual {
        _send(msg.sender, to, amount, userData, "", false);
    }

    /// @notice Allows an operator to send tokens on behalf of another address.
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
    ) public virtual {
        require(isOperatorFor(msg.sender, from), "ERC777: Address is not an operator for holder.");
        _send(from, to, amount, userData, operatorData, false);
    }

    /// @notice Burns an amount of the caller's tokens.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data associated with the burn
    function burn(uint256 amount, bytes calldata userData) public virtual {
        _burn(msg.sender, amount, userData, "", false);
    }

    /// @notice Allows an operator to burn tokens on behalf of another address.
    /// @param from The address whose tokens are being burned.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data associated with the burn.
    /// @param operatorData Additional data about the operator.
    function operatorBurn(address from, uint256 amount, bytes calldata userData, bytes calldata operatorData)
        public
        virtual
    {
        require(isOperatorFor(msg.sender, from), "ERC777: Address is not an operator for holder.");
        _burn(from, amount, userData, operatorData, false);
    }

    /// @dev Internal function to authorize an operator to manage the caller's tokens.
    /// Emits an {AuthorizedOperator} event.
    /// @param operator The address to authorize.
    function _authorizeOperator(address operator) internal virtual {
        require(operator != msg.sender, "ERC777: Holder is always an operator for itself.");
        if (_defaultOperators[operator]) {
            delete _revokedDefaultOperators[msg.sender][operator];
        } else {
            _operators[msg.sender][operator] = true;
        }
        emit AuthorizedOperator(operator, msg.sender);
    }

    /// @dev Internal function to revoke an operator's rights to manage the caller's tokens.
    /// Emits a {RevokedOperator} event.
    /// @param operator The address to revoke.
    function _revokeOperator(address operator) internal virtual {
        require(operator != msg.sender, "ERC777: Holder is always an operator for itself.");
        if (_defaultOperators[operator]) {
            _revokedDefaultOperators[msg.sender][operator] = true;
        } else {
            delete _operators[msg.sender][operator];
        }
        emit RevokedOperator(operator, msg.sender);
    }

    /// @dev Internal function to check if an amount is a valid multiple of granularity.
    /// @param amount The amount to check.
    /// @return True if the amount is a valid multiple of granularity, false otherwise.
    function _isValidGranularity(uint256 amount) internal view returns (bool) {
        return amount % _granularity == 0;
    }

    /// @dev Call `tokensToSend()` on an implementer if one is registered for the
    /// sender of the tokens (`from`).
    ///
    /// See {ERC777TokenSender}.
    ///
    /// @param operator Operator requesting the transfer.
    /// @param from Token holder address.
    /// @param to Token recipient address.
    /// @param amount Amount of tokens to be transferred.
    /// @param userData Extra information provided by the token holder (if any).
    /// @param operatorData Extra information provided by the operator (if any).
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            ERC777TokensSender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }

    /// @dev Call `tokensReceived()` on an implementer if one is registered for the
    /// receiver of the tokens (`to`).
    /// Reverts if `requireReceptionAck` is true and the recipient is a contract but
    /// `tokensReceived()` was not registered for the recipient.
    ///
    /// See {ERC777TokenRecipient}.
    ///
    /// @param operator Operator requesting the transfer.
    /// @param from Token holder address.
    /// @param to Token recipient address.
    /// @param amount Amount of tokens to be transferred.
    /// @param userData Extra information provided by the token holder (if any).
    /// @param operatorData Extra information provided by the operator (if any).
    /// @param requireReceptionAck If `true`, contract recipients are required to
    /// implement {ERC777TokensRecipient}.
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            ERC777TokensRecipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            require(!Address.isContract(to), "ERC777: Recipient contract has no implementer for ERC777TokensRecipient");
        }
    }

    /// @dev See {_mint}
    function _mint(address account, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        virtual
    {
        _mint(account, amount, userData, operatorData, true);
    }

    /// @dev Creates `amount` tokens and assigns them to `account`, increasing
    /// the total supply.
    ///
    /// If `requireReceptionAck` is set to true, and if a send hook is
    /// registered for `account`, the corresponding function will be called with
    /// `operator`, `data` and `operatorData`.
    ///
    /// See {ERC777TokenRecipient}.
    ///
    /// Emits the {Minted} event.
    ///
    /// Requirements
    ///
    /// - `account` cannot be the zero address.
    /// - if `account` is a contract, it must implement the {ERC777TokenRecipient} interface.
    ///
    /// @param account Operator requesting the transfer.
    /// @param amount Amount of tokens to be transferred.
    /// @param userData Extra information provided by the token holder (if any).
    /// @param operatorData Extra information provided by the operator (if any).
    /// @param requireReceptionAck If `true`, contract recipients are required to
    /// implement {ERC777TokensRecipient}.
    function _mint(
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(account != address(0), "ERC777: Cannot mint to the zero address");
        require(_isValidGranularity(amount), "ERC777: Amount is not a multiple of granularity");

        _callTokensToSend(msg.sender, address(0), account, amount, userData, operatorData);

        _totalSupply += amount;
        _balances[account] += amount;

        _callTokensReceived(msg.sender, address(0), account, amount, userData, operatorData, requireReceptionAck);

        emit Minted(msg.sender, account, amount, userData, operatorData);
    }

    /// @dev See {_send}
    function _send(address from, address to, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        virtual
    {
        _send(from, to, amount, userData, operatorData, true);
    }

    /// @dev Sends `amount` tokens from `from` address to `to` address,
    /// decreasing `from` balance by that `amount` and increasing `to`
    /// balance by that same `amount`.
    ///
    /// If `requireReceptionAck` is set to true, and if a send hook is
    /// registered for `to`, the corresponding function will be called with
    /// `from`, `userData` and `operatorData`.
    ///
    /// See {ERC777TokenSender} and {ERC777TokenRecipient}.
    ///
    /// Emits the {Sent} event.
    ///
    /// Requirements
    ///
    /// - `from` cannot be the zero address.
    /// - `to` cannot be the zero address.
    /// - if `from` is a contract, it may implement the {ERC777TokenSender} interface.
    /// - if `requireReceptionAck` is true and `to` is a contract, it must implement
    /// the {ERC777TokenRecipient} interface.
    ///
    /// @param from Tokens holder.
    /// @param to Tokens recipient.
    /// @param amount Amount of tokens to be transferred.
    /// @param userData Extra information provided by the token holder (if any).
    /// @param operatorData Extra information provided by the operator (if any).
    /// @param requireReceptionAck If `true`, contract recipients are required to
    /// implement {ERC777TokensRecipient}.
    function _send(
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(from != address(0), "ERC777: Sender cannot be the zero address.");
        require(to != address(0), "ERC777: Receiver cannot be the zero address.");
        require(_isValidGranularity(amount), "ERC777: Amount is not a multiple of granularity");

        _callTokensToSend(msg.sender, from, to, amount, userData, operatorData);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: Transfer amount exceeds balance.");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Sent(msg.sender, from, to, amount, userData, operatorData);

        _callTokensReceived(msg.sender, from, to, amount, userData, operatorData, requireReceptionAck);
    }

    /// @dev See {_burn}
    function _burn(address from, uint256 amount, bytes memory userData, bytes memory operatorData) internal virtual {
        _burn(from, amount, userData, operatorData, true);
    }

    /// @dev Burns `amount` tokens from `from` address, decreasing `from` balance
    /// by that `amount` and decreasing `totalSupply` by that same `amount`.
    ///
    /// Emits the {Burned} event.
    ///
    /// Requirements
    ///
    /// - `from` cannot be the zero address.
    /// - if `from` is a contract, it must implement the {ERC777TokenSender} interface.
    ///
    /// @param from Tokens holder.
    /// @param amount Amount of tokens to be burned.
    /// @param userData Extra information provided by the token holder (if any).
    /// @param operatorData Extra information provided by the operator (if any).
    /// @param requireReceptionAck If `true`, contract recipients are required to
    /// implement {ERC777TokensRecipient}.
    function _burn(
        address from,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(from != address(0), "ERC777: Sender cannot be the zero address.");
        require(_isValidGranularity(amount), "ERC777: amount is not a multiple of granularity");

        _callTokensToSend(msg.sender, from, address(0), amount, userData, operatorData);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: Burn amount exceeds balance.");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _totalSupply -= amount;
        _callTokensReceived(msg.sender, from, address(0), amount, userData, operatorData, requireReceptionAck);

        emit Burned(msg.sender, from, amount, userData, operatorData);
    }

    /// @dev Sets the `defaultOperators` for the token. See {ERC777Token-defaultOperators}.
    /// @param defaultOperators_ The default operators to be set.
    function _setDefaultOperators(address[] memory defaultOperators_) internal virtual {
        // Reset previous values to false, if any
        for (uint256 i = 0; i < _defaultOperatorsArray.length; i++) {
            _defaultOperators[_defaultOperatorsArray[i]] = false;
        }
        // Set new operators
        _defaultOperatorsArray = defaultOperators_;
        for (uint256 i = 0; i < defaultOperators_.length; i++) {
            _defaultOperators[defaultOperators_[i]] = true;
        }
    }
}
