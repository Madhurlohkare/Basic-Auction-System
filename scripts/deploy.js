async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying TimedAuction contract with account:", deployer.address);

  const TimedAuction = await ethers.getContractFactory("TimedAuction");
  const timedAuction = await TimedAuction.deploy();

  await timedAuction.deployed();

  console.log("TimedAuction deployed to:", timedAuction.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
