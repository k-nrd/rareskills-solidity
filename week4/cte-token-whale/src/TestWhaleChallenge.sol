// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TokenWhaleChallenge} from "./TokenWhaleChallenge.sol";

contract TestWhaleChallenge is TokenWhaleChallenge {
    address echidna = msg.sender;

    event Debug(address who);

    constructor() TokenWhaleChallenge(echidna) {}

    function echidna_cannot_increase_balance() public returns (bool) {
        emit Debug(echidna);
        return !isComplete();
    }
}
