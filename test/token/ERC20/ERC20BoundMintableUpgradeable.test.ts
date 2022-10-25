import { fail } from "assert";
import { expect } from "chai";
import { ethers, upgrades, web3 } from "hardhat";
import expectRevert from "../../utils/expectRevert";

const NAME = "My Token";
const SYMBOL = "MT";

const DEFAULT_MINTING_CAP = ethers.utils.parseEther('1000');
const PER_ADDRESS_MINTING_CAP_MORE_THAN_DEFAULT = ethers.utils.parseEther('10000');
const PER_ADDRESS_MINTING_CAP_LESS_THAN_DEFAULT = ethers.utils.parseEther('100');

const ROLE_MINTER = web3.utils.soliditySha3('MINTER_ROLE');
const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';

describe('ERC20BoundMintableUpgradeable', () => {

    async function loadFixture() {
        const ERC20BoundMintableUpgradeable = await ethers.getContractFactory("ERC20BoundMintableMockUpgradeable");
        const token = await upgrades.deployProxy(ERC20BoundMintableUpgradeable, [NAME, SYMBOL, DEFAULT_MINTING_CAP]);

        const [ admin, minter ] = await ethers.getSigners();

        return { token, minter, admin };
    }

    describe('Minting process', () => {

        it('should allow MINTER to mint tokens until default cap is exceeded', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            await token.connect(minter).mint(admin.address, DEFAULT_MINTING_CAP);
            await expectRevert(token.connect(minter).mint(admin.address, 1), "ERC20BoundMintableUpgradeable: minting cap exceeded");
        });

        [
            { value: DEFAULT_MINTING_CAP, caption: "per-address cap equal to default exceeded" },
            { value: PER_ADDRESS_MINTING_CAP_MORE_THAN_DEFAULT, caption: "per-address cap less than default exceeded" },
            { value: PER_ADDRESS_MINTING_CAP_LESS_THAN_DEFAULT, caption: "per-address cap more than default exceeded" }
        ].forEach(
            param => it(`should allow MINTER to mint tokens until ${param.caption}`, async () => {
                const { token, minter, admin } = await loadFixture();

                await token["addMinter(address,uint256)"](minter.address, param.value);
    
                await token.connect(minter).mint(admin.address, param.value);
                await expectRevert(token.connect(minter).mint(admin.address, 1), "ERC20BoundMintableUpgradeable: minting cap exceeded");
            })
        );

        it('should return amount of minted tokens by given minter', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address,uint256)"](minter.address, PER_ADDRESS_MINTING_CAP_MORE_THAN_DEFAULT);

            const tokensToMint = PER_ADDRESS_MINTING_CAP_MORE_THAN_DEFAULT.div(2);

            await token.connect(minter).mint(admin.address, tokensToMint);
            const mintedTokens = await token.amountOfMintedTokens(minter.address);

            expect(mintedTokens).to.eq(tokensToMint);
        });

        it('should revert if called mintingCap with non-minter', async () => {
            const { token, minter } = await loadFixture();

            await expectRevert(token.mintingCap(minter.address), "ERC20BoundMintableUpgradeable: Not a minter");
        });

        it('should revert if called amountOfMintedTokens with non-minter', async () => {
            const { token, minter } = await loadFixture();

            await expectRevert(token.amountOfMintedTokens(minter.address), "ERC20BoundMintableUpgradeable: Not a minter");
        });

        it('should return cap of minted tokens by given minter', async () => {
            const { token, minter } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            const tokensCap = await token.mintingCap(minter.address);

            expect(tokensCap).to.eq(DEFAULT_MINTING_CAP);
        });
    }); 

    describe('Minting access rights', () => {
        it('should return true if account isMinter()', async () => {
            const { token, minter, admin } = await loadFixture();

            await token.connect(admin)["addMinter(address)"](minter.address);

            expect(await token.isMinter(minter.address)).to.true;
        });

        it('should return false if account not isMinter()', async () => {
            const { token, minter } = await loadFixture();

            expect(await token.isMinter(minter.address)).to.false;
        });

        it('should allow user with admin role to add minter', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.true;
        });

        it('should allow user with admin role to remove minter', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.true;
            await token.connect(admin).removeMinter(minter.address);
            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.false;
        });

        it('should allow minter to renounce', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.true;
            await token.connect(minter).renounceMinter();
            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.false;
        });

        it('should prohibit user without admin role to remove minter', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);

            await expectRevert(token.connect(minter).removeMinter(admin.address), `AccessControl: account ${minter.address.toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE?.toLowerCase()}`);
        });

        it('should prohibit user without admin role to add minter', async () => {
            const { token, minter } = await loadFixture();

            await token["addMinter(address)"](minter.address);
            
            await expectRevert(token.connect(minter)["addMinter(address)"](minter.address), `AccessControl: account ${minter.address.toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE?.toLowerCase()}`);
        });

        it('should revert if non-minter tries to renounce', async () => {
            const { token, minter, admin } = await loadFixture();

            await expectRevert(token.connect(admin).renounceMinter(), `AccessControl: account ${admin.address.toLowerCase()} is missing role ${ROLE_MINTER?.toLowerCase()}`);
        });

        it('should revert if trying to add a minter address as a minter', async () => {
            const { token, minter, admin } = await loadFixture();

            await token["addMinter(address)"](minter.address);
            expect(await token.hasRole(ROLE_MINTER, minter.address)).to.true;
            await expectRevert(token.connect(admin)["addMinter(address)"](minter.address), "ERC20BoundMintableUpgradeable: Already a minter");
        });

        it('should revert if trying to removeMinter() with a non-minter address', async () => {
            const { token, admin } = await loadFixture();

            await expectRevert(token.connect(admin).removeMinter(admin.address), "ERC20BoundMintableUpgradeable: Not a minter");
        });
    });
});
