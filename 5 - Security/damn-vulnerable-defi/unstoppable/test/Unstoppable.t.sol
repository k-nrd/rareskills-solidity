// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {UnstoppableVault} from "../src/Unstoppable.sol";
import {UnstoppableExploiter} from "../src/UnstoppableExploiter.sol";
import {ReceiverUnstoppable} from "../src/ReceiverUnstoppable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract DamnValuableToken is ERC20 {
    constructor() ERC20("DamnValuableToken", "DVT", 18) {
        _mint(msg.sender, type(uint256).max);
    }
}

contract UnstoppableExploiterTest is Test {
    ERC20 token;
    UnstoppableVault vault;
    UnstoppableExploiter exploiter;
    address vaultOwner = vm.addr(1);
    address feeReceiver = vm.addr(2);
    address player = vm.addr(3);

    uint256 constant TOKENS_IN_VAULT = 1000000 * 10 ** 18;
    uint256 constant INITIAL_PLAYER_TOKEN_BALANCE = 10 * 10 ** 18;

    function setUp() public {
        // Challenge setup
        DamnValuableToken _token = new DamnValuableToken();
        token = ERC20(address(_token));
        vault = new UnstoppableVault(token, vaultOwner, feeReceiver);

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, address(this));

        exploiter = new UnstoppableExploiter(address(vault), address(token));

        token.transfer(address(exploiter), INITIAL_PLAYER_TOKEN_BALANCE);

        vm.deal(address(exploiter), 1 ether);
        vm.deal(address(vault), 1000 ether);

        // Show its possible for some user to take out a flash loan
        ReceiverUnstoppable receiver = new ReceiverUnstoppable(address(vault));
        receiver.executeFlashLoan(100 * 10 ** 18);
    }

    function test_SetUpOk() public view {
        assertEq(address(vault.asset()), address(token));
        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50000 * 10 ** 18);
        assertEq(token.balanceOf(address(exploiter)), INITIAL_PLAYER_TOKEN_BALANCE);
    }

    function test_Attack() public {
        exploiter.attack();

        // Can't loan anymore (Invalid Balance)
        ReceiverUnstoppable receiver = new ReceiverUnstoppable(address(vault));
        vm.expectRevert();
        receiver.executeFlashLoan(100 * 10 ** 18);
    }
}
