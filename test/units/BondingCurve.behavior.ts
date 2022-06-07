import { expect } from "chai";
import {Contract} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

export function shouldBehaveLikeBondingCurve(): void {
    describe("Check Token Price with Bonding Curve", async function () {
        let crowdFunding: Contract;
        let owner: SignerWithAddress;

        beforeEach(async () => {
            [owner] = this.ctx.signers;
            crowdFunding = this.ctx.crowdFunding;
        });

        it("check token`s buy price", async function () {
            // for(let i=10402; i<120000; i*= 1.24){
            //     const price1 = await crowdFunding.getBuyPrice(Math.floor(i));
            //     console.log('price: ', Number(i), ':',  price1);
            // }
            expect(await crowdFunding.getBuyPrice(10402)).to.eq(10);
            expect(await crowdFunding.getBuyPrice(24593)).to.eq(80);
            expect(await crowdFunding.getBuyPrice(46890)).to.eq(365);
            expect(await crowdFunding.getBuyPrice(89402)).to.eq(1645);
            expect(await crowdFunding.getBuyPrice(137465)).to.eq(4491);
            expect(await crowdFunding.getBuyPrice(211366)).to.eq(12323);
        });

        it("check token`s sell price", async function () {
            // for(let i=10402; i<120000; i*= 1.24){
            //     const price1 = await crowdFunding.getSellPrice(Math.floor(i));
            //     console.log('price: ', Number(i), ':',  price1);
            // }
            expect(await crowdFunding.getSellPrice(10402)).to.eq(9);
            expect(await crowdFunding.getSellPrice(24593)).to.eq(72);
            expect(await crowdFunding.getSellPrice(46890)).to.eq(328);
            expect(await crowdFunding.getSellPrice(89402)).to.eq(1480);
            expect(await crowdFunding.getSellPrice(137465)).to.eq(4041);
            expect(await crowdFunding.getSellPrice(211366)).to.eq(11090);
        });
    });
}
