import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

task("rinkeby:CrowdFunding", "Deploy CrowdFunding")
    .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
        /// Deploy CrowdFunding
        const CrowdFunding = await ethers.getContractFactory("CrowdFunding");
        const constructorArgs = [taskArguments.name, taskArguments.coinAddress, taskArguments.price, taskArguments.start, taskArguments.end, taskArguments.minThreshold];
        const crowdFunding = await upgrades.deployProxy(CrowdFunding,constructorArgs);
        await crowdFunding.deployed();

        console.log("CrowdFunding deployed to:", crowdFunding.address);
    });
