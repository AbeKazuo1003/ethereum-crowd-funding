import { expect } from "chai";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from 'ethers';

export function shouldBehaveLikeOwnerable(): void {
    describe("Ownable", async function() {
        let owner: SignerWithAddress;
        let addr1: SignerWithAddress;
        let addr2: SignerWithAddress;
        let crowdFunding: Contract;

        beforeEach(async () => {
            [owner, addr1, addr2] = this.ctx.signers;
            crowdFunding = this.ctx.crowdFunding;
        });

        it("Owner is able to transfer ownership", async () => {

            await expect(crowdFunding.transferOwnership(addr1.address))
                .to.emit(crowdFunding, 'OwnershipTransferred')

        });


        it("No Owner is not able to transfer ownership", async () => {

            await crowdFunding.transferOwnership(addr1.address);

            await expect(crowdFunding.transferOwnership(addr2.address))
                .to.be.revertedWith('Ownable: caller is not the owner')
        });

    });
}
