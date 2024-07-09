// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {GaslessExchange} from "../src/GaslessExchange.sol";
import {SwapOffer, Order, Permit, SignedOrder, SignedPermit} from "../src/GaslessExchangeEIP712.sol";
import {GaslessExchangeEIP712Utils} from "./GaslessExchangeEIP712Utils.sol";

contract PermitToken is ERC20, ERC20Permit {
    constructor(
        string memory _name,
        string memory _symbol,
        address _to
    ) ERC20Permit(_name) ERC20(_name, _symbol) {
        _mint(_to, 1_000_000);
    }
}

contract GaslessExchangeTest is Test {
    ERC20Permit internal tokenA;
    ERC20Permit internal tokenB;
    GaslessExchange internal gaslessExchange;
    GaslessExchangeEIP712Utils internal gaslessUtils;

    uint256 internal user1PrivateKey;
    uint256 internal user2PrivateKey;
    address internal user1;
    address internal user2;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function setUp() public {
        user1PrivateKey = 0xA11CE;
        user1 = vm.addr(user1PrivateKey);
        user2PrivateKey = 0xFACADE;
        user2 = vm.addr(user2PrivateKey);

        tokenA = new PermitToken("TokenA", "A", user1);
        tokenB = new PermitToken("TokenB", "B", user2);
        gaslessExchange = new GaslessExchange(tokenA, tokenB);
        gaslessUtils = new GaslessExchangeEIP712Utils(gaslessExchange);
    }

    function test_swap() public {
        SignedPermit memory signedPermitA = getTokenASignedPermit(100);
        SignedPermit memory signedPermitB = getTokenBSignedPermit(5);
        SignedOrder memory signedOrderA = getTokenASignedOrder(100, 50);
        SignedOrder memory signedOrderB = getTokenBSignedOrder(5, 10);
        SwapOffer memory swapOfferA = getSwapOffer(signedOrderA, signedPermitA);
        SwapOffer memory swapOfferB = getSwapOffer(signedOrderB, signedPermitB);

        gaslessExchange.swap(swapOfferA, swapOfferB);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenA.balanceOf(user2), 10);
        assertEq(tokenB.balanceOf(user1), 5);
    }

    function test_swap_equal_volume() public {
        SignedPermit memory signedPermitA = getTokenASignedPermit(100);
        SignedPermit memory signedPermitB = getTokenBSignedPermit(50);
        SignedOrder memory signedOrderA = getTokenASignedOrder(100, 50);
        SignedOrder memory signedOrderB = getTokenBSignedOrder(50, 100);
        SwapOffer memory swapOfferA = getSwapOffer(signedOrderA, signedPermitA);
        SwapOffer memory swapOfferB = getSwapOffer(signedOrderB, signedPermitB);

        gaslessExchange.swap(swapOfferA, swapOfferB);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenA.balanceOf(user2), 100);
        assertEq(tokenB.balanceOf(user1), 50);
    }

    function test_swap_a_less() public {
        SignedPermit memory signedPermitA = getTokenASignedPermit(10);
        SignedPermit memory signedPermitB = getTokenBSignedPermit(50);
        SignedOrder memory signedOrderA = getTokenASignedOrder(10, 5);
        SignedOrder memory signedOrderB = getTokenBSignedOrder(50, 100);
        SwapOffer memory swapOfferA = getSwapOffer(signedOrderA, signedPermitA);
        SwapOffer memory swapOfferB = getSwapOffer(signedOrderB, signedPermitB);

        gaslessExchange.swap(swapOfferA, swapOfferB);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenA.balanceOf(user2), 10);
        assertEq(tokenB.balanceOf(user1), 5);
    }

    function test_swap_switch_ratios() public {
        SignedPermit memory signedPermitA = getTokenASignedPermit(10);
        SignedPermit memory signedPermitB = getTokenBSignedPermit(150);
        SignedOrder memory signedOrderA = getTokenASignedOrder(10, 15);
        SignedOrder memory signedOrderB = getTokenBSignedOrder(150, 100);
        SwapOffer memory swapOfferA = getSwapOffer(signedOrderA, signedPermitA);
        SwapOffer memory swapOfferB = getSwapOffer(signedOrderB, signedPermitB);

        gaslessExchange.swap(swapOfferA, swapOfferB);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenA.balanceOf(user2), 10);
        assertEq(tokenB.balanceOf(user1), 15);
    }

    function test_swap_flat_ratio() public {
        SignedPermit memory signedPermitA = getTokenASignedPermit(10);
        SignedPermit memory signedPermitB = getTokenBSignedPermit(150);
        SignedOrder memory signedOrderA = getTokenASignedOrder(10, 10);
        SignedOrder memory signedOrderB = getTokenBSignedOrder(150, 150);
        SwapOffer memory swapOfferA = getSwapOffer(signedOrderA, signedPermitA);
        SwapOffer memory swapOfferB = getSwapOffer(signedOrderB, signedPermitB);

        gaslessExchange.swap(swapOfferA, swapOfferB);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);
        assertEq(tokenA.balanceOf(user2), 10);
        assertEq(tokenB.balanceOf(user1), 10);
    }

    function test_permit_tokenA() public {
        executePermit(getTokenASignedPermit(1));

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 0);

        vm.prank(address(gaslessExchange));
        tokenA.transferFrom(user1, address(gaslessExchange), 1);

        assertEq(tokenA.balanceOf(address(gaslessExchange)), 1);
    }

    function test_permit_tokenB() public {
        executePermit(getTokenBSignedPermit(1));

        assertEq(tokenB.balanceOf(address(gaslessExchange)), 0);

        vm.prank(address(gaslessExchange));
        tokenB.transferFrom(user2, address(gaslessExchange), 1);

        assertEq(tokenB.balanceOf(address(gaslessExchange)), 1);
    }

    function test_orders_validity() public {
        assertTrue(
            gaslessExchange.isValidOrder(getTokenASignedOrder(1 ether, 1 ether))
        );
        assertTrue(
            gaslessExchange.isValidOrder(getTokenBSignedOrder(1 ether, 1 ether))
        );
    }

    /* HELPERS */
    function getTokenASignedPermit(
        uint256 _value
    ) internal view returns (SignedPermit memory) {
        return
            gaslessUtils.getSignedPermit(
                tokenA,
                address(gaslessExchange),
                _value,
                user1PrivateKey
            );
    }

    function getTokenBSignedPermit(
        uint256 _value
    ) internal view returns (SignedPermit memory) {
        return
            gaslessUtils.getSignedPermit(
                tokenB,
                address(gaslessExchange),
                _value,
                user2PrivateKey
            );
    }

    function getTokenASignedOrder(
        uint256 amountOut,
        uint256 amountIn
    ) internal view returns (SignedOrder memory) {
        return
            gaslessUtils.getSignedOrder(
                address(tokenA),
                address(tokenB),
                amountOut,
                amountIn,
                user1PrivateKey
            );
    }

    function getTokenBSignedOrder(
        uint256 amountOut,
        uint256 amountIn
    ) internal view returns (SignedOrder memory) {
        return
            gaslessUtils.getSignedOrder(
                address(tokenB),
                address(tokenA),
                amountOut,
                amountIn,
                user2PrivateKey
            );
    }

    function getSwapOffer(
        SignedOrder memory _signedOrder,
        SignedPermit memory _signedPermit
    ) internal pure returns (SwapOffer memory swapOffer) {
        swapOffer.signedOrder = _signedOrder;
        swapOffer.signedPermit = _signedPermit;
    }

    function executePermit(SignedPermit memory signedPermit) internal {
        Permit memory permit = signedPermit.permit;
        if (permit.owner == user1) {
            tokenA.permit(
                permit.owner,
                permit.spender,
                permit.value,
                permit.deadline,
                signedPermit.v,
                signedPermit.r,
                signedPermit.s
            );
        } else {
            tokenB.permit(
                permit.owner,
                permit.spender,
                permit.value,
                permit.deadline,
                signedPermit.v,
                signedPermit.r,
                signedPermit.s
            );
        }
    }
}
