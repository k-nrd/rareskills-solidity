// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DamnValuableTokenPermit} from "../src/DamnValuableTokenPermit.sol";

contract DeployScript is Script {
    function run() external {
        vm.broadcast();
        new DamnValuableTokenPermit("DamnValuableTokenPermit", "DVTP");
    }
}
