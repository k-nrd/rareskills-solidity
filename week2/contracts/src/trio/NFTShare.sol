// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract CryptoHipposShare is ERC20 {
    constructor() ERC20("CryptoHipposShare", "CHPS") {}
}
