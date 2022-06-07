import { expect } from "chai";
import {Contract} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {AFTER_ONE_HOUR_TIMESTAMP, TIMESTAMP_NOW} from "../helper";
const { upgrades, ethers } = require('hardhat');

export function shouldBehaveLikeUpgradeable(): void {
    describe("Version 2/Set Treasury Address", async function () {
        let crowdFunding: Contract;
        let owner: SignerWithAddress;

        beforeEach(async () => {
            [owner] = this.ctx.signers;

            const CrowdFundingV2Factory = await ethers.getContractFactory("CrowdFundingV2", owner);

            // Upgrade to Version 2
            this.ctx.crowdFunding = await upgrades.upgradeProxy(this.ctx.crowdFunding.address, CrowdFundingV2Factory);

            crowdFunding = this.ctx.crowdFunding;
            //   console.log('CrowdFunding Upgraded V1 => V2 : ' + this.ctx.crowdFunding.address);
        });

        it("keep data after upgrading", async function () {
            expect(await crowdFunding.startTimestamp()).to.eq(TIMESTAMP_NOW);
            expect(await crowdFunding.endTimestamp()).to.eq(AFTER_ONE_HOUR_TIMESTAMP);
        });
    });
}
