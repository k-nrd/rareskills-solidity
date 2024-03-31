// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TokenWhaleChallenge} from "./TokenWhaleChallenge.sol";

contract TestWhaleChallenge is TokenWhaleChallenge {
    address echidna = msg.sender;

    ERC20 token;
    UnstoppableVault pool;
    UnstoppableExploiter exploiter;
    ReceiverUnstoppable receiver;
    address vaultOwner = address(1);
    address feeReceiver = address(2);

    constructor() {
        token = new Tok();
        pool = new UnstoppableVault(token, vaultOwner, feeReceiver);
        receiver = new ReceiverUnstoppable(address(pool));
        exploiter = new UnstoppableExploiter(address(pool), address(receiver));
    }

    function echidna_cannot_increase_balance() public returns (bool) {
        emit Debug(echidna);
        return !isComplete();
    }
}
