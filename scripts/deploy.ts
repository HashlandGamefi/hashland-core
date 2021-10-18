import hre, { ethers } from "hardhat";

async function main() {
  const constructorArgs: any[] = [
    "0x13A4d213DCd17A42EDabd18bFfc2E5146fC58a61",
    2000000,
    "0x105A80A5Da83997c32818716846BB609C5Ffe35d",
    "0x105A80A5Da83997c32818716846BB609C5Ffe35d",
  ];
  const factory = await ethers.getContractFactory("HNUpgrade");
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployed();
  console.log("HNUpgrade contract successfully deployed:", contract.address)
  await hre.run("verify:verify", {
    address: contract.address,
    constructorArguments: constructorArgs
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
