// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DexTwo, SwappableTokenTwo} from "../src/DexTwo.sol";
import {DexTwoAttacker} from "../src/DexTwoAttacker.sol";

contract DexTwoTest is Test {
    DexTwo public dex;
    SwappableTokenTwo public tok1;
    SwappableTokenTwo public tok2;
    address public player = address(1);

    function setUp() public {
        // Use a random account as owner
        dex = new DexTwo();
        tok1 = new SwappableTokenTwo(address(dex), "Token One", "TK1", 1000);
        tok2 = new SwappableTokenTwo(address(dex), "Token Two", "TK2", 1000);

        // Ethernaut setup
        tok1.approve(address(dex), tok1.balanceOf(address(this)));
        tok2.approve(address(dex), tok2.balanceOf(address(this)));
        dex.setTokens(address(tok1), address(tok2));
        dex.add_liquidity(address(tok1), 100);
        dex.add_liquidity(address(tok2), 100);
        tok1.transfer(player, 10);
        tok2.transfer(player, 10);

        // So test runner can't cheat for us
        dex.renounceOwnership();
    }

    function test_Attack() public {
        DexTwoAttacker attacker = new DexTwoAttacker();
        attacker.attack(dex, address(tok1), tok1.balanceOf(address(dex)), player);
        attacker.attack(dex, address(tok2), tok2.balanceOf(address(dex)), player);
        assertEq(IERC20(dex.token1()).balanceOf(player), 110);
    }
}
