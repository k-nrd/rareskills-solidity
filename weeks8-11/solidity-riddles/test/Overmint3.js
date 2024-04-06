const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const NAME = "Overmint3"

describe(NAME, function() {
  async function setup() {
    const [owner, attackerWallet] = await ethers.getSigners();

    const VictimFactory = await ethers.getContractFactory(NAME);
    const victimContract = await VictimFactory.deploy();

    return { victimContract, attackerWallet };
  }

  describe("exploit", async function() {
    let victimContract, attackerWallet;
    before(async function() {
      ({ victimContract, attackerWallet } = await loadFixture(setup));
    })

    it("conduct your attack here", async function() {
      const overrides = {
        gasPrice: 10000000000, // Can set this >= to the number read from Ganache window
        gasLimit: 6721975, // Use the same gasLimit as read from Ganache window (or a bit higher if still having issue)
      };
      const attackerProxy = await ethers.getContractFactory("Overmint3AttackerProxy")
      await attackerProxy.connect(attackerWallet).deploy(victimContract.address, overrides)
    });

    after(async function() {
      expect(await victimContract.balanceOf(attackerWallet.address)).to.be.equal(5);
      expect(await ethers.provider.getTransactionCount(attackerWallet.address)).to.equal(1, "must exploit one transaction");
    });
  });
});
