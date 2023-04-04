// SPDX-License-Identifier: AGPL-3.0-or-later

import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  ERC20SharesTest,
  ERC20SharesTest__factory,
} from "../contracts/typechain/index";
import { ethers } from "ethers";

use(solidity);

describe("ERC20SharesTest", async () => {
  const [w0, w1, w2, w3] = new MockProvider().getWallets();

  let erc20Shares: ERC20SharesTest;

  before(async () => {
    erc20Shares = (await deployContract(
      w0,
      ERC20SharesTest__factory as any,
      [ethers.utils.parseEther("1000000")] // 1M shares
    )) as ERC20SharesTest;
    // w0 now has 1M shares.

    // Transfer 150K shares to w1.
    await erc20Shares
      .connect(w0)
      .transfer(w1.address, ethers.utils.parseEther("150000"));

    // Transfer 200K shares to w2.
    await erc20Shares
      .connect(w0)
      .transfer(w2.address, ethers.utils.parseEther("200000"));
  });

  let receiveBlock1: number;
  let receiveBlock2: number;
  let receiveBlock3: number;

  describe("sending value", () => {
    it("just works", async () => {
      let tx = await w3.sendTransaction({
        to: erc20Shares.address,
        value: ethers.utils.parseEther("42"),
      });

      receiveBlock1 = (await tx.wait()).blockNumber;

      tx = await w3.sendTransaction({
        to: erc20Shares.address,
        value: ethers.utils.parseEther("69"),
      });

      receiveBlock2 = (await tx.wait()).blockNumber;
    });
  });

  describe("harvesting", () => {
    before(async () => {
      await erc20Shares.connect(w2).setHarvestPremium(10); // 10/255
    });

    it("works with single block", async () => {
      let w1BalanceBefore = await w1.getBalance();
      await erc20Shares.connect(w0).harvestBatch(w1.address, [receiveBlock1]);
      let w1BalanceAfter = await w1.getBalance();

      expect(w1BalanceAfter.sub(w1BalanceBefore)).to.eq(
        ethers.utils.parseEther("42").mul(150000).div(1000000)
      );
    });

    describe("after token balance change", async () => {
      before(async () => {
        // Increase w1's token balance by 25K.
        await erc20Shares
          .connect(w0)
          .transfer(w1.address, ethers.utils.parseEther("25000"));

        // w1's past shares should still be 150K/1M.
        expect(
          await erc20Shares.getPastShares(w1.address, receiveBlock2)
        ).to.eq(ethers.utils.parseEther("150000"));
        expect(await erc20Shares.getPastTotalShares(receiveBlock2)).to.eq(
          ethers.utils.parseEther("1000000")
        );
      });

      it("works", async () => {
        let w1BalanceBefore = await w1.getBalance();
        await erc20Shares.connect(w0).harvestBatch(w1.address, [receiveBlock2]);
        let w1BalanceAfter = await w1.getBalance();

        // The receive happened before the transfer, so w1 should still get the 150K/1M share.
        expect(w1BalanceAfter.sub(w1BalanceBefore)).to.eq(
          ethers.utils.parseEther("69").mul(150000).div(1000000)
        );
      });
    });

    describe("after another receive", async () => {
      before(async () => {
        let tx = await w3.sendTransaction({
          to: erc20Shares.address,
          value: ethers.utils.parseEther("17"),
        });

        receiveBlock3 = (await tx.wait()).blockNumber;
      });

      it("works", async () => {
        let w1BalanceBefore = await w1.getBalance();
        await erc20Shares.connect(w0).harvestBatch(w1.address, [receiveBlock3]);
        let w1BalanceAfter = await w1.getBalance();

        expect(w1BalanceAfter.sub(w1BalanceBefore)).to.eq(
          ethers.utils.parseEther("17").mul(175000).div(1000000)
        );
      });
    });

    it("works with multiple blocks and premium", async () => {
      const w0BalanceBefore = await w0.getBalance();
      const w2BalanceBefore = await w2.getBalance();
      const tx = await erc20Shares
        .connect(w0)
        .harvestBatch(w2.address, [receiveBlock1, receiveBlock2]);
      const txGasCost = tx.gasPrice!.mul(tx.gasLimit);
      const w2BalanceAfter = await w2.getBalance();
      const w0BalanceAfter = await w0.getBalance();

      const dividend1 = ethers.utils.parseEther("42").mul(200000).div(1000000);
      const dividend2 = ethers.utils.parseEther("69").mul(200000).div(1000000);
      const totalDividend = dividend1.add(dividend2);

      const premium1 = dividend1.mul(10).div(255);
      const premium2 = dividend2.mul(10).div(255);
      const totalPremium = premium1.add(premium2);

      // w2 gets the amount minus the premium.
      expect(w2BalanceAfter.sub(w2BalanceBefore)).to.eq(
        totalDividend.sub(totalPremium)
      );

      // w0 gets the premium.
      expect(w0BalanceAfter.sub(w0BalanceBefore)).to.eq(
        totalPremium.sub(txGasCost)
      );
    });
  });
});
