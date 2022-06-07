const { upgrades, ethers } = require('hardhat');

import {AFTER_ONE_HOUR_TIMESTAMP, TIMESTAMP_NOW} from "./helper";
import {shouldBehaveLikeOwnerable} from "./units/Ownerable.behavior";
import {shouldBehaveLikePausable} from "./units/Pausable.behavior";
import {shouldBehaveLikeUpgradeable} from "./units/Upgradable.behavior";
import {shouldBehaveLikeBondingCurve} from "./units/BondingCurve.behavior";
import {shouldBehaveLikeSetProps} from "./units/SetProps.behavior";

const PROJECT_NAME = "MyFunding";
const INIT_COIN_PRICE = 50;
const FUNDING_COIN_SUPPLY = 20000;
const MIN_FUNDING_THRESHOLD = 10000;

describe("CrowdFunding", function () {


  beforeEach(async () => {

    this.ctx.signers = await ethers.getSigners();
    const [owner, addr1, addr2, addr3] = this.ctx.signers;

    /// Test Stable Coin Deploy
    const StableCoin = await ethers.getContractFactory("StableCoin", owner);
    this.ctx.stableCoin = await StableCoin.deploy("Tether USD", "USDT", 1000000);
    await this.ctx.stableCoin.deployed();

    await this.ctx.stableCoin.transfer(addr1.address, 10000);
    await this.ctx.stableCoin.transfer(addr2.address, 10000);
    await this.ctx.stableCoin.transfer(addr3.address, 10000);

    /// Test Project Coin Deploy
    const ProjectCoin = await ethers.getContractFactory("ProjectCoin", owner);
    this.ctx.projectCoin = await ProjectCoin.deploy("Test Project Coin", "TPC", 1000000);
    await this.ctx.projectCoin.deployed();

    /// Deploy CrowdFunding
    const CrowdFunding = await ethers.getContractFactory("CrowdFunding", owner);
    const constructorArgs = [PROJECT_NAME, this.ctx.projectCoin.address, INIT_COIN_PRICE, TIMESTAMP_NOW, AFTER_ONE_HOUR_TIMESTAMP, MIN_FUNDING_THRESHOLD];
    this.ctx.crowdFunding = await upgrades.deployProxy(CrowdFunding,constructorArgs);
    await this.ctx.crowdFunding.deployed();

    /// Allocate Funding Project Coin to CrowdFunding
    await this.ctx.projectCoin.approve(this.ctx.crowdFunding.address, FUNDING_COIN_SUPPLY);
    await this.ctx.crowdFunding.connect(owner).allocateSupply(FUNDING_COIN_SUPPLY);

    this.ctx.crowdFunding.setStableCoin(this.ctx.stableCoin.address);
  });

  shouldBehaveLikeOwnerable();

  shouldBehaveLikePausable();

  shouldBehaveLikeUpgradeable();

  shouldBehaveLikeBondingCurve();

  shouldBehaveLikeSetProps();
});
