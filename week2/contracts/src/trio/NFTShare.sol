// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20PrivateMint} from "../lib/ERC20PrivateMint.sol";

contract NFTShare is ERC20PrivateMint {
    constructor(address _vault) ERC20PrivateMint("CryptoHipposShare", "CHPS", _vault) {}
}
