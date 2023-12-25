// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20Private} from "../lib/ERC20Private.sol";

contract NFTShare is ERC20Private {
    constructor(address _vault) ERC20Private("CryptoHipposShare", "CHPS", _vault) {}
}
