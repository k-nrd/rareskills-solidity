// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TokenWhale} from "./TokenWhale.sol";

contract TestWhale is TokenWhale {
    address echidna = msg.sender;

    event Debug(address who);

    constructor() TokenWhale(echidna) {}

    function echidna_cannot_increase_balance() public returns (bool) {
        emit Debug(echidna);
        return !isComplete();
    }
}
