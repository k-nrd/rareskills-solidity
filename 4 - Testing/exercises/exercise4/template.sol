// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./token.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --test-mode assertion
///      ```
///      or by providing a config
///      ```
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --config program-analysis/echidna/exercises/exercise4/config.yaml
///      ```
contract TestToken is Token {
    function transfer(address to, uint256 value) public override {
        // Pre-condition
        uint256 initialFromBalance = balances[msg.sender];
        uint256 initialToBalance = balances[to];

        // Action
        super.transfer(to, value);

        // Post-condition
        assert(balances[msg.sender] <= initialFromBalance);
        assert(balances[to] >= initialToBalance);
    }
}
