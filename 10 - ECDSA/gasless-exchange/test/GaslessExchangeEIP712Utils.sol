// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {GaslessExchange} from "../src/GaslessExchange.sol";
import {PERMIT_TYPEHASH, ORDER_TYPEHASH, Order, Permit, SignedOrder, SignedPermit} from "../src/GaslessExchangeEIP712.sol";

contract GaslessExchangeEIP712Utils is Test {
    GaslessExchange public gaslessExchange;

    constructor(GaslessExchange _gaslessExchange) {
        gaslessExchange = _gaslessExchange;
    }

    function getStructHash(
        Order memory _order
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    _order.owner,
                    _order.tokenOut,
                    _order.tokenIn,
                    _order.amountOut,
                    _order.amountIn,
                    _order.nonce,
                    _order.deadline
                )
            );
    }

    function getStructHash(
        Permit memory _permit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    _permit.owner,
                    _permit.spender,
                    _permit.value,
                    _permit.nonce,
                    _permit.deadline
                )
            );
    }

    function getTypedDataHash(
        Order memory _order
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toTypedDataHash(
                gaslessExchange.DOMAIN_SEPARATOR(),
                getStructHash(_order)
            );
    }

    function getTypedDataHash(
        ERC20Permit _token,
        Permit memory _permit
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toTypedDataHash(
                _token.DOMAIN_SEPARATOR(),
                getStructHash(_permit)
            );
    }

    function getFakeTypedDataHash(
        Order memory _order
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    hex"1902",
                    gaslessExchange.DOMAIN_SEPARATOR(),
                    getStructHash(_order)
                )
            );
    }

    function getFakeTypedDataHash(
        Permit memory _permit
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    hex"1902",
                    gaslessExchange.DOMAIN_SEPARATOR(),
                    getStructHash(_permit)
                )
            );
    }

    function getSignedOrder(
        address tokenOut,
        address tokenIn,
        uint256 amountOut,
        uint256 amountIn,
        uint256 _privateKey
    ) public view returns (SignedOrder memory signedOrder) {
        address owner = vm.addr(_privateKey);

        signedOrder.order = Order({
            owner: owner,
            tokenOut: tokenOut,
            tokenIn: tokenIn,
            amountOut: amountOut,
            amountIn: amountIn,
            nonce: gaslessExchange.nonces(owner),
            deadline: block.timestamp + 1000
        });

        (signedOrder.v, signedOrder.r, signedOrder.s) = vm.sign(
            _privateKey,
            getTypedDataHash(signedOrder.order)
        );
    }

    function getSignedPermit(
        ERC20Permit _permitToken,
        address spender,
        uint256 value,
        uint256 _privateKey
    ) public view returns (SignedPermit memory signedPermit) {
        address owner = vm.addr(_privateKey);

        signedPermit.permit = Permit({
            owner: owner,
            spender: spender,
            value: value,
            nonce: _permitToken.nonces(owner),
            deadline: block.timestamp + 1000
        });

        (signedPermit.v, signedPermit.r, signedPermit.s) = vm.sign(
            _privateKey,
            getTypedDataHash(_permitToken, signedPermit.permit)
        );
    }
}
