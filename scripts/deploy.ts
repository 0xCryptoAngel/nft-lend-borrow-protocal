import { ethers } from "hardhat";
import { IPikachu } from "../typechain-types/contracts/Master.sol/Pikachu";

async function main() {
  const defaultAdminSetting: IPikachu.AdminSettingStruct = {
    feeTo: "",
    minDepositAmount: ethers.utils.parseEther("0.1"),
    verifiedCollections: [],
    platformFee: 250,
    blockNumberSlippage: 300,
  };
  const [owner, otherAccount] = await ethers.getSigners();
  defaultAdminSetting.feeTo = owner.address;
  defaultAdminSetting.verifiedCollections = [owner.address];
  const Pikachu = await ethers.getContractFactory("Pikachu");
  const pikachu = await Pikachu.deploy(defaultAdminSetting);

  console.log(pikachu.address, await ethers.provider.getBlockNumber());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
