import { expect } from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {Contract} from "ethers";

export function shouldBehaveLikePausable(): void {
    describe("Pausable", async function() {
        let owner: SignerWithAddress;
        let addr1: SignerWithAddress;
        let addr2: SignerWithAddress;
        let crowdFunding: Contract;

        beforeEach(async () =>{
            [owner, addr1, addr2] = this.ctx.signers;
            crowdFunding = this.ctx.crowdFunding;
        });


        it("Owner is able to pause when NOT paused", async () => {
            await expect(crowdFunding.pause())
                .to.emit(crowdFunding, 'Paused')
                .withArgs(owner.address);
        });


        it("Owner is able to unpause when already paused", async () => {
            await crowdFunding.pause();

            await expect(crowdFunding.unpause())
                .to.emit(crowdFunding, 'Unpaused')
                .withArgs(owner.address);
        });

        it("Owner is NOT able to pause when already paused", async () => {
            await crowdFunding.pause();

            await expect(crowdFunding.pause())
                .to.be.revertedWith("Pausable: paused");
        });

        it("Owner is NOT able to unpause when already unpaused", async () => {
            await crowdFunding.pause();

            await crowdFunding.unpause();

            await expect(crowdFunding.unpause())
                .to.be.revertedWith("Pausable: not paused");
        });
    });
}
