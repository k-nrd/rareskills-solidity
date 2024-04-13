// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GatekeeperOne} from "../src/GatekeeperOne.sol";
import {GatekeeperOneAttacker} from "../src/GatekeeperOneAttacker.sol";

contract GatekeeperOneTest is Test {
    GatekeeperOne target;
    GatekeeperOneAttacker attacker;

    function setUp() public {
        target = new GatekeeperOne();
        attacker = new GatekeeperOneAttacker();
    }

    function test_Attack() public {
        uint256 i = 0;
        while (gasleft() % 8196 != 0) {
            i++;
        }
        (bool ok,) = address(attacker).call{gas: gasleft()}(abi.encodeCall(attacker.attack, (target)));
        require(ok, "attack failed");
    }

    function test_Gateone() public {
        uint256 startGas = gasleft();
        require(msg.sender == tx.origin, "GatekeeperOne: msg.sender is tx.origin");
        uint256 gasSpent = startGas - gasleft();

        emit log_uint(gasSpent);
    }
}
