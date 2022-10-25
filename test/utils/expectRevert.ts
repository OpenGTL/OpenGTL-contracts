import { expect } from "chai";

const expectRevert = (promise: Promise<any>, revertMessage: string) => expect(promise).to.be.revertedWith(revertMessage);

export default expectRevert;
