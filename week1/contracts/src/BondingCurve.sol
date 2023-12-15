// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC777} from "./lib/ERC777.sol";

/// @title BondingCurveToken
/// @notice An ERC777 token implemented with a linear bonding curve and slippage tolerance.
/// @dev This contract allows users to buy and sell tokens at prices determined by a linear bonding curve.
///      It includes mechanisms for slippage tolerance and reentrancy protection.
/// @author Gustavo Konrad
contract BondingCurveToken is ERC777 {
    /// @notice Baseline price for the bonding curve.
    uint256 public baseline = 10_000 gwei;

    /// @notice Rate of price increase for the bonding curve.
    uint256 public rate = 100 gwei;

    /// @notice Current price per token, adjusted by the bonding curve.
    uint256 public price = baseline;

    /// @notice Indicates if a function is currently being executed, used for reentrancy guard.
    bool private locked = false;

    event Buy();
    event Sell();

    /// @notice Constructor to create BondingCurveToken
    /// @param name_ Name of the token.
    /// @param symbol_ Symbol of the token.
    constructor(string memory name_, string memory symbol_) ERC777(name_, symbol_, 0, 1) {}

    /// @dev Modifier to adjust the token price after operations that change the supply.
    modifier updatesPrice() {
        _;
        _adjustPrice();
    }

    /// @dev Modifier to prevent reentrancy.
    modifier locks() {
        require(!locked, "Can't execute this function more than once per call");
        locked = true;
        _;
        locked = false;
    }

    /// @notice Burns a specific amount of tokens.
    /// @dev Burns tokens and updates the token price.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data provided by the token holder (if any).
    function burn(uint256 amount, bytes calldata userData) public override {
        _burn(msg.sender, amount, userData, "");
    }

    /// @notice Allows an operator to burn tokens on behalf of a token holder.
    /// @dev Burns tokens from the specified address and updates the token price.
    /// @param from The address from which tokens will be burned.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function operatorBurn(address from, uint256 amount, bytes calldata userData, bytes calldata operatorData)
        public
        override
    {
        require(isOperatorFor(msg.sender, from), "Caller is not an operator for address.");
        _burn(from, amount, userData, operatorData);
    }

    /// @notice Allows users to buy tokens with Ether, specifying a minimum number of tokens to receive.
    /// @param minTokens The minimum number of tokens the buyer is willing to accept.
    /// @param userData Additional data provided by the token holder (if any).
    function buy(uint256 minTokens, bytes calldata userData) external payable {
        _buy(minTokens, msg.sender, userData, "");
    }

    /// @notice Allows operators to buy tokens on behalf of a token holder.
    /// @param minTokens The minimum number of tokens the buyer is willing to accept.
    /// @param to The address receiving the bought tokens.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function operatorBuy(uint256 minTokens, address to, bytes calldata userData, bytes calldata operatorData)
        public
        payable
    {
        require(isOperatorFor(msg.sender, to), "Caller is not an operator for address.");
        _buy(minTokens, to, userData, operatorData);
    }

    /// @notice Allows users to sell tokens for Ether, specifying a minimum amount of Ether to receive.
    /// @param minEth The minimum amount of Ether the seller is willing to accept.
    /// @param amount The amount of tokens to sell.
    /// @param userData Additional data provided by the token holder (if any).
    function sell(uint256 minEth, uint256 amount, bytes calldata userData) external {
        _sell(minEth, msg.sender, amount, userData, "");
    }

    /// @notice Allows operators to sell tokens on behalf of a token holder.
    /// @param minEth Minimum amount of Ether the seller is willing to accept.
    function operatorSell(
        uint256 minEth,
        address from,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) public {
        require(isOperatorFor(msg.sender, from), "Caller is not an operator for address.");
        _sell(minEth, from, amount, userData, operatorData);
    }

    /// @notice Internal function to handle buying tokens with Ether.
    /// @dev Checks the slippage tolerance before executing the buy, locks and updates price when done.
    /// @param minTokens The minimum number of tokens the buyer is willing to accept.
    /// @param to The address receiving the bought tokens.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function _buy(uint256 minTokens, address to, bytes memory userData, bytes memory operatorData) internal virtual {
        require(_isValidGranularity(minTokens), "minTokens must have a valid granularity");
        uint256 tokens = _toTokens(msg.value);
        require(tokens >= minTokens, "Slippage tolerance exceeded");
        // _mint will check if the resulting amount of tokens has a valid granularity
        // _mint will also check if the `to` address is valid
        _mint(to, tokens, userData, operatorData);
    }

    /// @notice Internal function to handle selling tokens for Ether.
    /// @dev Checks the slippage tolerance before executing the sell, locks and updates price when done.
    /// @param minEth The minimum amount of Ether the seller is willing to accept.
    /// @param from The address selling the tokens.
    /// @param amount The amount of tokens to sell.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function _sell(uint256 minEth, address from, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        virtual
    {
        uint256 eth = _toEther(amount);
        require(address(this).balance >= eth, "Contract does not have enough Ether in the balance.");
        require(eth >= minEth, "Slippage tolerance exceeded");
        _burn(from, amount, userData, operatorData);
        (bool ok,) = payable(from).call{value: eth}("");
        require(ok, "Failed to send Ether to seller");
    }

    /// @notice Internal mint function.
    /// @dev Should be used internally to execute sells. Locks and updates price when done.
    /// @param from The address for which tokens will be minted.
    /// @param amount The amount of tokens to mint.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function _mint(address from, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        override
        locks
        updatesPrice
    {
        _mint(from, amount, userData, operatorData, false);
    }

    /// @notice Internal burn function.
    /// @dev Should be used internally to execute burns and buys. Locks and updates price when done.
    /// @param from The address from which tokens will be burned.
    /// @param amount The amount of tokens to burn.
    /// @param userData Additional data provided by the token holder (if any).
    /// @param operatorData Additional data provided by the operator (if any).
    function _burn(address from, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        override
        locks
        updatesPrice
    {
        _burn(from, amount, userData, operatorData, false);
    }

    /// @notice Adjusts the token price based on the current total supply.
    /// @dev The price is adjusted according to a linear bonding curve.
    function _adjustPrice() internal virtual {
        price = rate * totalSupply() + baseline;
    }

    /// @notice Converts a given Ether value to its equivalent in tokens.
    /// @param value The amount of Ether to convert.
    /// @return The equivalent number of tokens.
    function _toTokens(uint256 value) internal virtual returns (uint256) {
        return value / price;
    }

    /// @notice Converts a given token amount to its equivalent Ether value.
    /// @param tokens The amount of tokens to convert.
    /// @return The equivalent Ether value.
    function _toEther(uint256 tokens) internal virtual returns (uint256) {
        return tokens * price;
    }

    /// @notice Fallback function to handle direct Ether transfers to the contract.
    /// @dev Automatically initiates a token purchase with no minimum token requirement.
    receive() external payable {}
}
