// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

struct Order {
    address owner;
    address tokenOut;
    address tokenIn;
    uint256 amountOut;
    uint256 amountIn;
    uint256 nonce;
    uint256 deadline;
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
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct SignedPermit {
    Permit permit;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct SwapOffer {
    SignedOrder signedOrder;
    SignedPermit signedPermit;
}

bytes32 constant ORDER_TYPEHASH = keccak256(
    "Order(address owner,address tokenOut,address tokenIn,uint256 amountOut,uint256 amountIn,uint256 nonce,uint256 deadline)"
);

bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);
