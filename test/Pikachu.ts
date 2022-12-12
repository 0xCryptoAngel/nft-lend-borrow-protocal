import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Pikachu } from "../typechain-types";
import { IPikachu } from "../typechain-types/contracts/Master.sol/Pikachu";
import { BigNumber } from "ethers";

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
    const [owner, secondAccount, thirdAccount] = await ethers.getSigners();
    defaultAdminSetting.feeTo = owner.address;

    const TestNFT = await ethers.getContractFactory("TestNFT");
    const validTestNFT = await TestNFT.deploy();
    const inValidTestNFT = await TestNFT.deploy();

    defaultAdminSetting.verifiedCollections = [validTestNFT.address];

    const Pikachu = await ethers.getContractFactory("Pikachu");
    const pikachu = await Pikachu.deploy(defaultAdminSetting);

    return {
      pikachu,
      validTestNFT,
      inValidTestNFT,
      owner,
      secondAccount,
      thirdAccount,
    };
  }

  async function deployContractAndCreatePool() {
    const {
      pikachu,
      validTestNFT,
      inValidTestNFT,
      owner,
      secondAccount,
      thirdAccount,
    } = await loadFixture(deployEmptyContract);

    await validTestNFT
      .connect(thirdAccount)
      .awardItem(thirdAccount.address, "", {
        value: ethers.utils.parseEther("1"),
      });

    await validTestNFT.connect(thirdAccount).approve(pikachu.address, 0);

    await pikachu
      .connect(secondAccount)
      .createPool(
        50,
        ethers.utils.parseEther("1"),
        0,
        500,
        400,
        86400 * 15,
        true,
        [validTestNFT.address],
        { value: ethers.utils.parseEther("10") }
      );

    return {
      pikachu,
      validTestNFT,
      inValidTestNFT,
      owner,
      secondAccount,
      thirdAccount,
    };
  }

  async function contractWithPoolAndLoan() {
    const {
      pikachu,
      validTestNFT,
      inValidTestNFT,
      owner,
      secondAccount,
      thirdAccount,
    } = await loadFixture(deployContractAndCreatePool);

    const collectionInfo = {
      address: validTestNFT.address,
      floorPrice: ethers.utils.parseEther("0.7"),
      blockNumber: await ethers.provider.getBlockNumber(),
    };

    const hash = await pikachu.getMessageHash(
      collectionInfo.address,
      collectionInfo.floorPrice,
      collectionInfo.blockNumber
    );

    const signature = await owner.signMessage(ethers.utils.arrayify(hash));
    await pikachu
      .connect(thirdAccount)
      .borrow(
        secondAccount.address,
        validTestNFT.address,
        0,
        86400,
        ethers.utils.parseEther("0.35"),
        signature,
        collectionInfo.floorPrice,
        collectionInfo.blockNumber
      );
    return {
      pikachu,
      validTestNFT,
      inValidTestNFT,
      owner,
      secondAccount,
      thirdAccount,
    };
  }

  describe("Deployment", function () {
    it("Should set the right admin settings", async function () {
      const { pikachu, secondAccount } = await loadFixture(deployEmptyContract);

      //  expect(await lock.unlockTime()).to.equal(unlockTime);
      // console.log(await pikachu.getPoolByOwner(owner.address));
      const adminSetting = await pikachu.adminSetting();
      expect(adminSetting.feeTo).to.equal(defaultAdminSetting.feeTo);
      expect(adminSetting.minDepositAmount).to.equal(
        defaultAdminSetting.minDepositAmount
      );
      await expect(
        pikachu.connect(secondAccount).updateAdminSetting(defaultAdminSetting)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
  describe("Create Pool", function () {
    it("Should create pool with only valid NFT collections", async function () {
      const { pikachu, inValidTestNFT, thirdAccount } = await loadFixture(
        deployContractAndCreatePool
      );

      await expect(
        pikachu
          .connect(thirdAccount)
          .createPool(
            50,
            ethers.utils.parseEther("0.1"),
            0,
            500,
            400,
            86400 * 15,
            true,
            [inValidTestNFT.address],
            { value: ethers.utils.parseEther("0.1") }
          )
      ).to.be.revertedWith("createPool: Unsupported collections provided");
    });

    it("Should update pool", async function () {
      const { pikachu, validTestNFT, inValidTestNFT, secondAccount } =
        await loadFixture(deployContractAndCreatePool);
      await pikachu
        .connect(secondAccount)
        .updatePool(
          60,
          ethers.utils.parseEther("1"),
          1,
          550,
          600,
          87600 * 30,
          false,
          [validTestNFT.address],
          { value: ethers.utils.parseEther("1") }
        );

      const newPool = await pikachu.getPoolById(0);
      expect(newPool.depositedAmount).equals(ethers.utils.parseEther("11"));
      expect(newPool.availableAmount).equals(ethers.utils.parseEther("11"));

      expect(await ethers.provider.getBalance(pikachu.address)).equals(
        ethers.utils.parseEther("11")
      );
    });

    it("Should loan", async function () {
      const { pikachu, validTestNFT, owner, secondAccount, thirdAccount } =
        await loadFixture(deployContractAndCreatePool);

      const collectionInfo = {
        address: validTestNFT.address,
        floorPrice: ethers.utils.parseEther("0.7"),
        blockNumber: await ethers.provider.getBlockNumber(),
      };

      const hash = await pikachu.getMessageHash(
        collectionInfo.address,
        collectionInfo.floorPrice,
        collectionInfo.blockNumber
      );

      const signature = await owner.signMessage(ethers.utils.arrayify(hash));
      const oldBalance = await thirdAccount.getBalance();
      const tx = await pikachu
        .connect(thirdAccount)
        .borrow(
          secondAccount.address,
          validTestNFT.address,
          0,
          86400,
          ethers.utils.parseEther("0.35"),
          signature,
          collectionInfo.floorPrice,
          collectionInfo.blockNumber
        );
      const receipt = await tx.wait();
      // const gasCost = receipt.cumulativeGasUsed.add(receipt.effectiveGasPrice);
      const gasCost = receipt.cumulativeGasUsed.add(receipt.effectiveGasPrice);

      const currentBalance = await thirdAccount.getBalance();
      expect(currentBalance.add(gasCost).sub(oldBalance).toString())
        .to.be.gte(ethers.utils.parseEther("0.349"), "Not enough ETH received")
        .to.be.lte(ethers.utils.parseEther("0.35"), "Incorrect ETH received");
      // await expect(
      //   (await thirdAccount.getBalance())
      //     .add(gasCost)
      //     .sub(ethers.utils.parseEther("0.35"))
      // ).to.be.equals(oldBalance);

      expect(await validTestNFT.ownerOf(0)).to.be.equals(pikachu.address);
    });

    it("Should repay", async function () {
      const { pikachu, secondAccount, thirdAccount } = await loadFixture(
        contractWithPoolAndLoan
      );
      expect(
        await pikachu.calculateRepayAmount(
          86400 * 10,
          0,
          500,
          400,
          ethers.utils.parseEther("1")
        )
      ).to.be.equals(ethers.utils.parseEther("1.45"));
      expect(
        await pikachu.calculateRepayAmount(
          86400 * 9,
          1,
          500,
          400,
          ethers.utils.parseEther("1")
        )
      ).to.be.equals(ethers.utils.parseEther("1.17"));
      expect(
        await pikachu.calculateRepayAmount(
          86400 * 36,
          1,
          500,
          400,
          ethers.utils.parseEther("1")
        )
      ).to.be.equals(ethers.utils.parseEther("1.29"));

      await time.increase(86400 * 10);

      await pikachu.connect(thirdAccount).repay(secondAccount.address, {
        value: ethers.utils.parseEther("0.5075"),
      });
    });
  });
});
