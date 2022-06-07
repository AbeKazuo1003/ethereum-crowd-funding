import { expect } from "chai";
import {Contract} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {getTimestamp} from "../helper";

const BEFORE_ONE_MINUTE_TIMESTAMP = getTimestamp(new Date()) - 60;
const AFTER_ONE_MINUTE_TIMESTAMP = getTimestamp(new Date()) + 60;

export function shouldBehaveLikeSetProps(): void {
    describe("Check Setting CrowdFunding Props by Project Owner", async function () {
        let crowdFunding: Contract;
        let owner: SignerWithAddress;
        let addr1: SignerWithAddress;
        let addr2: SignerWithAddress;

        beforeEach(async () => {
            [owner, addr1, addr2] = this.ctx.signers;
            crowdFunding = this.ctx.crowdFunding;
        });

        it("set start Timestamp by only owner", async function () {
            await expect(crowdFunding.setStartTimestamp(BEFORE_ONE_MINUTE_TIMESTAMP)).to.revertedWith('Funding already started');
            await expect(crowdFunding.connect(addr1).setStartTimestamp(BEFORE_ONE_MINUTE_TIMESTAMP)).to.revertedWith('Ownable: caller is not the owner');
        });

        it("set end Timestamp by only owner", async function () {
            await expect(crowdFunding.setEndTimestamp(BEFORE_ONE_MINUTE_TIMESTAMP)).to.revertedWith('Start timestamp < End Timestamp');
            await expect(crowdFunding.connect(addr1).setEndTimestamp(AFTER_ONE_MINUTE_TIMESTAMP)).to.revertedWith('Ownable: caller is not the owner');
        });

        it("set min.threshold by only owner", async function () {
            await expect(crowdFunding.setMinFundingThreshold(0)).to.revertedWith('MIN.Threshold must be greater than zero');
            await expect(crowdFunding.connect(addr1).setMinFundingThreshold(10000)).to.revertedWith('Ownable: caller is not the owner');
        });

        it("set wallet address by only owner", async function () {
            await crowdFunding.setWalletAddress(addr2.address);
            expect(await crowdFunding.walletAddress()).to.eq(addr2.address);
        });
    });
}
