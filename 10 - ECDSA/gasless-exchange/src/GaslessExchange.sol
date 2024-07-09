// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SwapOffer, SignedOrder, SignedPermit, Order, ORDER_TYPEHASH} from "./GaslessExchangeEIP712.sol";

contract GaslessExchange is EIP712("GaslessExchange", "1"), Nonces {
    error InvalidOrder(address owner, uint256 nonce);
    error InvalidPair(
        address orderAOwner,
        address orderBOwner,
        uint256 nonceA,
        uint256 nonceB
    );

    ERC20Permit public immutable token0;
    ERC20Permit public immutable token1;

    constructor(ERC20Permit _token0, ERC20Permit _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function swap(
        SwapOffer memory swapOfferA,
        SwapOffer memory swapOfferB
    ) external {
        (SignedOrder memory orderA, SignedPermit memory permitA) = (
            swapOfferA.signedOrder,
            swapOfferA.signedPermit
        );
        (SignedOrder memory orderB, SignedPermit memory permitB) = (
            swapOfferB.signedOrder,
            swapOfferB.signedPermit
        );

        if (!isValidOrder(orderA)) {
            revert InvalidOrder(orderA.order.owner, orderA.order.nonce);
        }
        if (!isValidOrder(orderB)) {
            revert InvalidOrder(orderB.order.owner, orderB.order.nonce);
        }
        if (!isValidOrderPair(orderA.order, orderB.order)) {
            revert InvalidPair(
                orderA.order.owner,
                orderB.order.owner,
                orderA.order.nonce,
                orderB.order.nonce
            );
        }

        // Permit sells
        ERC20Permit tokenOutA = ERC20Permit(orderA.order.tokenOut);
        ERC20Permit tokenOutB = ERC20Permit(orderB.order.tokenOut);

        tokenOutA.permit(
            permitA.permit.owner,
            permitA.permit.spender,
            permitA.permit.value,
            permitA.permit.deadline,
            permitA.v,
            permitA.r,
            permitA.s
        );
        tokenOutB.permit(
            permitB.permit.owner,
            permitB.permit.spender,
            permitB.permit.value,
            permitB.permit.deadline,
            permitB.v,
            permitB.r,
            permitB.s
        );

        // Execute swap using the smaller amounts (ratio was already validated)
        // If A wants to sell more than B wants to sell,
        // Use order B amounts. Else, use order A amounts.
        (uint256 tokenOutAAmount, uint256 tokenOutBAmount) = orderA
            .order
            .amountOut > orderB.order.amountOut
            ? (orderB.order.amountIn, orderB.order.amountOut)
            : (orderA.order.amountOut, orderA.order.amountIn);

        tokenOutA.transferFrom(
            orderA.order.owner,
            orderB.order.owner,
            tokenOutAAmount
        );
        tokenOutB.transferFrom(
            orderB.order.owner,
            orderA.order.owner,
            tokenOutBAmount
        );
    }

    function ratesMatch(
        Order memory orderA,
        Order memory orderB
    ) internal pure returns (bool) {
        if (orderA.amountOut == orderA.amountIn) {
            return true;
        } else if (orderA.amountOut > orderA.amountIn) {
            return
                orderA.amountOut / orderA.amountIn ==
                orderB.amountIn / orderB.amountOut;
        }
        return
            orderA.amountIn / orderA.amountOut ==
            orderB.amountOut / orderB.amountIn;
    }

    function isValidOrderPair(
        Order memory orderA,
        Order memory orderB
    ) public pure returns (bool) {
        return
            orderA.tokenOut == orderB.tokenIn &&
            orderA.tokenIn == orderB.tokenOut &&
            ratesMatch(orderA, orderB);
    }

    function isValidOrder(
        SignedOrder memory _signedOrder
    ) public returns (bool) {
        Order memory _order = _signedOrder.order;

        // Order expired
        if (block.timestamp > _order.deadline) {
            return false;
        }

        // Invalid tokens
        if (_order.tokenOut == _order.tokenIn) {
            return false;
        }
        if (
            _order.tokenOut != address(token0) &&
            _order.tokenOut != address(token1)
        ) {
            return false;
        }
        if (
            _order.tokenIn != address(token0) &&
            _order.tokenIn != address(token1)
        ) {
            return false;
        }

        return verifyOrder(_signedOrder);
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    function nonces(address owner) public view override returns (uint256) {
        return super.nonces(owner);
    }

    function verifyOrder(
        SignedOrder memory signedOrder
    ) internal returns (bool) {
        bytes32 structHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                signedOrder.order.owner,
                signedOrder.order.tokenOut,
                signedOrder.order.tokenIn,
                signedOrder.order.amountOut,
                signedOrder.order.amountIn,
                _useNonce(signedOrder.order.owner),
                signedOrder.order.deadline
            )
        );

        return
            ECDSA.recover(
                _hashTypedDataV4(structHash),
                signedOrder.v,
                signedOrder.r,
                signedOrder.s
            ) == signedOrder.order.owner;
    }
}
