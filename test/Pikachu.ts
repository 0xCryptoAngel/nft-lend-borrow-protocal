import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Pikachu } from "../typechain-types";
import { IPikachu } from "../typechain-types/contracts/Master.sol/Pikachu";

describe("Pikachu", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  const defaultAdminSetting: IPikachu.AdminSettingStruct = {
    feeTo: "",
    minDepositAmount: ethers.utils.parseEther("0.1"),
    verifiedCollections: [],
    platformFee: 250,
    blockNumberSlippage: 300,
  };
  async function deployEmptyContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    defaultAdminSetting.feeTo = owner.address;
    defaultAdminSetting.verifiedCollections = [owner.address];
    const Pikachu = await ethers.getContractFactory("Pikachu");
    const pikachu = await Pikachu.deploy(defaultAdminSetting);

    return { pikachu, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right admin settings", async function () {
      const { pikachu, otherAccount } = await loadFixture(deployEmptyContract);

      //  expect(await lock.unlockTime()).to.equal(unlockTime);
      // console.log(await pikachu.getPoolByOwner(owner.address));
      const adminSetting = await pikachu.adminSetting();
      expect(adminSetting.feeTo).to.equal(defaultAdminSetting.feeTo);
      expect(adminSetting.minDepositAmount).to.equal(
        defaultAdminSetting.minDepositAmount
      );
      pikachu
        .connect(otherAccount)
        .updateAdminSetting(defaultAdminSetting)
        .catch((error) => {
          expect(error.message).equal(
            "VM Exception while processing transaction: reverted with reason string 'Ownable: caller is not the owner'"
          );
        });
    });
  });
});
