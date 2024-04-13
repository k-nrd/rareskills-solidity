// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DexTwo} from "../src/DexTwo.sol";

contract DexTwoTest is Test {
    DexTwo public dex;

    function setUp() public {
        dex = new DexTwo();
    }

    function test_Increment() public {
        assertEq(true, true);
    }
}
