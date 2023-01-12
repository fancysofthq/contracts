// SPDX-License-Identifier: AGPL-3.0-or-later

import { ethers, BigNumberish, BytesLike } from "ethers";

export function encodeId(
  app: BytesLike,
  token: { contract: BytesLike; id: BigNumberish },
  seller: BytesLike
): BytesLike {
  return ethers.utils.solidityKeccak256(
    ["address", "address", "uint256", "address"],
    [app, token.contract, token.id, seller]
  );
}

export class Config {
  constructor(
    public readonly app: BytesLike,
    public readonly seller: BytesLike,
    public readonly price: BigNumberish
  ) {}

  encode(): BytesLike {
    return ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "uint256"],
      [this.app, this.seller, this.price]
    );
  }
}
