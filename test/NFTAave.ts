import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFTAave", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployEmptyContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const NFTAave = await ethers.getContractFactory("NFTAave");
    const nFTAave = await NFTAave.deploy();

    return { nFTAave, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { nFTAave, owner } = await loadFixture(deployEmptyContract);

      //  expect(await lock.unlockTime()).to.equal(unlockTime);
      console.log(await nFTAave.getPoolByOwner(owner.address));
    });
  });
});
