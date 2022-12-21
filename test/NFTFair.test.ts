// SPDX-License-Identifier: AGPL-3.0-or-later

import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  NFTFair,
  NFTFair__factory,
  ERC1155Dummy__factory,
  ERC1155Dummy,
} from "../contracts/typechain/index";
import { BigNumber, BytesLike, ethers } from "ethers";
import * as Listing from "../src/NFTFair/Listing";

use(solidity);

describe("NFTFair", async () => {
  const [w0, w1, w2, app, owner] = new MockProvider().getWallets();

  let erc1155Dummy: ERC1155Dummy;
  let nftStore: NFTFair;
  let listingId: BytesLike;

  before(async () => {
    erc1155Dummy = (await deployContract(
      owner,
      ERC1155Dummy__factory as any
    )) as ERC1155Dummy;

    nftStore = (await deployContract(
      owner,
      NFTFair__factory as any
    )) as NFTFair;

    listingId = Listing.encodeId(
      app.address,
      { contract: erc1155Dummy.address, id: 1 },
      w1.address
    );
  });

  describe("setting app fee", () => {
    it("should set app fee", async () => {
      await expect(nftStore.connect(app).setAppFee(app.address, 5))
        .to.emit(nftStore, "SetAppFee")
        .withArgs(app.address, 5);
      expect(await nftStore.getAppFee(app.address)).to.eq(5);
    });
  });

  describe("listing", () => {
    before(async () => {
      // Mint 50 tokens for w0.
      await erc1155Dummy.connect(w0).mint(w0.address, 1, 50, [], 10);

      // Transfer 40 tokens to w1.
      await erc1155Dummy
        .connect(w0)
        .safeTransferFrom(w0.address, w1.address, 1, 40, []);
    });

    describe("id", () => {
      it("should be correct", async () => {
        expect(listingId).to.eq(
          await nftStore.getListingId(
            app.address,
            { contractAddress: erc1155Dummy.address, tokenId: 1 },
            w1.address
          )
        );
      });
    });

    describe("when seller is invalid", () => {
      it("should fail", async () => {
        await expect(
          erc1155Dummy
            .connect(w1)
            .safeTransferFrom(
              w1.address,
              nftStore.address,
              1,
              10,
              new Listing.Config(
                app.address,
                w0.address,
                ethers.utils.parseEther("0.25")
              ).encode()
            )
        ).to.be.revertedWith("NFTFair: invalid seller");
      });
    });

    describe("when everything is set", () => {
      it("should list token", async () => {
        await erc1155Dummy
          .connect(w1)
          .safeTransferFrom(
            w1.address,
            nftStore.address,
            1,
            10,
            new Listing.Config(
              app.address,
              w1.address,
              ethers.utils.parseEther("0.25")
            ).encode()
          );

        // TODO:
        // .to.emit(nftStore, "List")
        // .withArgs(
        //   w1.address, // operator
        //   app.address, // app
        //   listingId, // listingId
        //   [erc1155Dummy.address, BigNumber.from(1)], // token
        //   ethers.utils.solidityKeccak256(
        //     ["address", "uint256"],
        //     [erc1155Dummy.address, 1]
        //   ), // tokenIndex
        //   w1.address, // seller
        //   ethers.utils.parseEther("0.25"), // price
        //   10 // stockSize
        // );

        const listing = await nftStore.getListing(listingId);

        expect(listing.config.seller).to.be.eq(w1.address);
        expect(listing.token.contractAddress).to.be.eq(erc1155Dummy.address);
        expect(listing.token.tokenId).to.be.eq(1);
        expect(listing.stockSize).to.be.eq(10);
        expect(listing.config.price).to.be.eq(ethers.utils.parseEther("0.25"));
        expect(listing.config.app).to.be.eq(app.address);
      });
    });
  });

  describe("purchasing", () => {
    describe("when value is less than required", () => {
      it("should fail", async () => {
        await expect(
          nftStore.connect(w2).purchase(listingId, 2, w2.address, {
            value: ethers.utils.parseEther("0.49"),
          })
        ).to.be.revertedWith("NFTFair: invalid value");
      });
    });

    describe("when the eth value is greater than required", () => {
      it("should fail", async () => {
        await expect(
          nftStore.connect(w2).purchase(listingId, 2, w2.address, {
            value: ethers.utils.parseEther("0.51"),
          })
        ).to.be.revertedWith("NFTFair: invalid value");
      });
    });

    it("should purchase token", async () => {
      // app receives app fee.
      const appBalanceBefore = await app.getBalance();

      // w0 is the royalty recipient.
      const w0BalanceBefore = await w0.getBalance();

      // w1 is the seller.
      const w1BalanceBefore = await w1.getBalance();

      // w2 is the buyer.
      const w2TokenBalanceBefore = await erc1155Dummy.balanceOf(w2.address, 1);

      await expect(
        nftStore.connect(w2).purchase(listingId, 2, w2.address, {
          value: ethers.utils.parseEther("0.5"),
        })
      )
        .to.emit(nftStore, "Purchase")
        .withArgs(
          w2.address, // operator
          app.address, // app
          listingId, // listingId
          w2.address, // buyer
          2, // tokenAmount
          w2.address, // sendTo
          ethers.utils.parseEther("0.5"), // Income
          w0.address, // royaltyAddress
          BigNumber.from("0x45a93abd01f5f5"), // royaltyValue
          BigNumber.from("0x2176f18cfe6ea0"), // appFee
          BigNumber.from("0x06893b2d89b19b6b") // profit
        );

      // w2 token balance should increase by 2.
      const w2TokenBalanceAfter = await erc1155Dummy.balanceOf(w2.address, 1);
      expect(w2TokenBalanceAfter).to.be.eq(w2TokenBalanceBefore.add(2));

      // w0 balance should increase by royalty.
      const w0BalanceAfter = await w0.getBalance();
      expect(w0BalanceAfter, "w0BalanceAfter").to.be.eq(
        w0BalanceBefore.add(ethers.utils.parseEther("0.019607843137254901"))
      );

      // app balance should increase by app fee.
      const appBalanceAfter = await app.getBalance();
      expect(appBalanceAfter, "appBalanceAfter").to.be.eq(
        appBalanceBefore.add(ethers.utils.parseEther("0.009419454056132256"))
      );

      // w1 balance should increase by profit.
      const w1BalanceAfter = await w1.getBalance();
      expect(w1BalanceAfter, "w1BalanceAfter").to.be.eq(
        w1BalanceBefore.add(ethers.utils.parseEther("0.470972702806612843"))
      );
    });

    describe("when insufficient stock", () => {
      it("should fail", async () => {
        await expect(
          nftStore.connect(w2).purchase(listingId, 49, w2.address, {
            value: ethers.utils.parseEther("12.25"),
          })
        ).to.be.revertedWith("NFTFair: insufficient stock");
      });
    });
  });

  describe("replenishing stock", () => {
    it("works", async () => {
      const listingStockSizeBefore = (await nftStore.getListing(listingId))
        .stockSize;

      await expect(
        erc1155Dummy
          .connect(w1)
          .safeTransferFrom(
            w1.address,
            nftStore.address,
            1,
            10,
            new Listing.Config(
              app.address,
              w1.address,
              ethers.utils.parseEther("0.35")
            ).encode()
          )
      )
        .to.emit(nftStore, "Replenish")
        .withArgs(w1.address, app.address, listingId, 10);

      const listing = await nftStore.getListing(listingId);

      expect(listing.stockSize, "stockSize").to.be.eq(
        listingStockSizeBefore.add(10)
      );

      expect(listing.config.price, "price").to.be.eq(
        ethers.utils.parseEther("0.35")
      );
    });
  });

  describe("withdrawing", () => {
    it("works", async () => {
      // w1 is seller.
      const w1TokenBalanceBefore = await erc1155Dummy.balanceOf(w1.address, 1);

      const listingStockSizeBefore = (await nftStore.getListing(listingId))
        .stockSize;

      await expect(nftStore.connect(w1).withdraw(listingId, 8, w1.address))
        .to.emit(nftStore, "Withdraw")
        .withArgs(w1.address, app.address, listingId, 8, w1.address);

      // w1 token balance should increase by 8.
      const w1TokenBalanceAfter = await erc1155Dummy.balanceOf(w1.address, 1);
      expect(w1TokenBalanceAfter, "w1TokenBalanceAfter").to.be.eq(
        w1TokenBalanceBefore.add(8)
      );

      // listing stock size should decrease by 8.
      const listingStockSizeAfter = await nftStore.getListing(listingId);
      expect(
        listingStockSizeAfter.stockSize,
        "listingStockSizeAfter.stockSize"
      ).to.be.eq(listingStockSizeBefore.sub(8));
    });
  });
});
