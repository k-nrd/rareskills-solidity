// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPermitToken} from "./IPermitToken.sol";

struct Order {
    address owner;
    address sellToken;
    address buyToken;
    uint256 sellAmount;
    uint256 buyAmount;
    uint256 expires;
    uint256 nonce;
}

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

struct SignedOrder {
    Order order;
    Permit permit;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract GaslessExchange is EIP712("GaslessExchange", "1") {
    error InvalidOrder(address owner, uint256 nonce);
    error InvalidPair(
        address orderAOwner,
        address orderBOwner,
        uint256 nonceA,
        uint256 nonceB
    );

    bytes32 public constant ORDER_TYPEHASH =
        keccak256(
            "Order(address owner,address sellToken,address buyToken,uint256 sellAmount,uint256 buyAmount,uint256 expires,uint256 nonce)"
        );

    IPermitToken public immutable token0;
    IPermitToken public immutable token1;

    mapping(address account => uint256) private nonces;

    constructor(IPermitToken _token0, IPermitToken _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function swap(
        SignedOrder memory signedOrderA,
        SignedOrder memory signedOrderB
    ) external {
        (Order memory orderA, Permit memory permitA) = (
            signedOrderA.order,
            signedOrderA.permit
        );
        (Order memory orderB, Permit memory permitB) = (
            signedOrderB.order,
            signedOrderB.permit
        );

        if (!isValidOrder(signedOrderA)) {
            revert InvalidOrder(orderA.owner, orderA.nonce);
        }
        if (!isValidOrder(signedOrderB)) {
            revert InvalidOrder(orderB.owner, orderB.nonce);
        }
        if (!isValidPair(orderA, orderB)) {
            revert InvalidPair(
                orderA.owner,
                orderB.owner,
                orderA.nonce,
                orderB.nonce
            );
        }

        // Permit sells
        IPermitToken(orderA.sellToken).permit(
            permitA.owner,
            permitA.spender,
            permitA.value,
            permitA.deadline,
            signedOrderA.v,
            signedOrderA.r,
            signedOrderA.s
        );
        IPermitToken(orderB.sellToken).permit(
            permitB.owner,
            permitB.spender,
            permitB.value,
            permitB.deadline,
            signedOrderB.v,
            signedOrderB.r,
            signedOrderB.s
        );

        // Use nonces
        nonces[orderA.owner] = orderA.nonce + 1;
        nonces[orderB.owner] = orderB.nonce + 1;

        // Execute swap using the smaller amounts (ratio is valid)
        // If A wants to buy less than B wants to sell, use orderA amounts
        // otherwise, use orderB amounts
        (uint256 token0Amount, uint256 token1Amount) = orderA.buyAmount <
            orderB.sellAmount
            ? (orderA.buyAmount, orderA.sellAmount)
            : (orderB.buyAmount, orderB.sellAmount);

        token0.transferFrom(orderA.owner, orderB.owner, token0Amount);
        token1.transferFrom(orderB.owner, orderA.owner, token1Amount);
    }

    function ratesMatch(
        Order memory orderA,
        Order memory orderB
    ) internal pure returns (bool) {
        if (orderA.sellAmount == orderA.buyAmount) {
            return true;
        } else if (orderA.sellAmount > orderA.buyAmount) {
            return
                orderA.sellAmount / orderA.buyAmount ==
                orderB.buyAmount / orderB.sellAmount;
        }
        return
            orderA.buyAmount / orderA.sellAmount ==
            orderB.sellAmount / orderB.buyAmount;
    }

    function isValidPair(
        Order memory orderA,
        Order memory orderB
    ) public pure returns (bool) {
        return
            orderA.sellToken == orderB.buyToken &&
            orderA.buyToken == orderB.sellToken &&
            ratesMatch(orderA, orderB);
    }

    function isValidOrder(
        SignedOrder memory signedOrder
    ) public view returns (bool) {
        // Order expired
        if (block.timestamp > signedOrder.order.expires) {
            return false;
        }

        // Nonce already used
        if (signedOrder.order.nonce < nonces[signedOrder.order.owner]) {
            return false;
        }

        // Invalid tokens
        if (signedOrder.order.sellToken == signedOrder.order.buyToken) {
            return false;
        }
        if (
            signedOrder.order.sellToken != address(token0) &&
            signedOrder.order.sellToken != address(token1)
        ) {
            return false;
        }
        if (
            signedOrder.order.buyToken != address(token0) &&
            signedOrder.order.buyToken != address(token1)
        ) {
            return false;
        }

        bytes32 structHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                signedOrder.order.owner,
                signedOrder.order.sellToken,
                signedOrder.order.buyToken,
                signedOrder.order.sellAmount,
                signedOrder.order.buyAmount,
                signedOrder.order.expires,
                signedOrder.order.nonce
            )
        );

        address signer = ECDSA.recover(
            _hashTypedDataV4(structHash),
            signedOrder.v,
            signedOrder.r,
            signedOrder.s
        );

        return signer != signedOrder.order.owner;
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}
