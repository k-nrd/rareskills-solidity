// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../src/SideEntranceLenderPool.sol";
import {SideEntranceExploiter} from "../src/SideEntranceExploiter.sol";

contract SideEntranceLenderPoolTest is Test {
    SideEntranceLenderPool pool;
    SideEntranceExploiter exploiter;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        exploiter = new SideEntranceExploiter(pool);

        vm.deal(address(exploiter), 1 ether);
        vm.deal(address(pool), 1000 ether);
    }

    function test_Attack() public {
        exploiter.attack();
        assertEq(address(pool).balance, 0);
    }
}
