const hre = require("hardhat");

async function main() {
  const PlayerDAO = await hre.ethers.getContractFactory("PlayerDAO");
  const deployedPlayerDAO = await PlayerDAO.deploy("PlayerDAO", "PlayerDAO");

  await deployedPlayerDAO.deployed();

  console.log("Deployed PlayerDAO Address:", deployedPlayerDAO.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
