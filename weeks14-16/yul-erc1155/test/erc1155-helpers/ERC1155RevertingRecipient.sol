// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155Received.selector)));
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155BatchReceived.selector)));
    }
}
