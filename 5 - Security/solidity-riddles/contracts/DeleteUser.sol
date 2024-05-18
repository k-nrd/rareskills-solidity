// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/**
 * This contract starts with 1 ether.
 * Your goal is to steal all the ether in the contract.
 *
 */
contract DeleteUser {
    struct User {
        address addr;
        uint256 amount;
    }

    User[] private users;

    function deposit() external payable {
        users.push(User({addr: msg.sender, amount: msg.value}));
    }

    function withdraw(uint256 index) external {
        User storage user = users[index];
        require(user.addr == msg.sender, "Can't withdraw from other users");
        uint256 amount = user.amount;

        // user = users[users.length - 1];
        user.amount = users[users.length - 1].amount;
        user.addr = users[users.length - 1].addr;
        users.pop();

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "withdraw failed");
    }
}
