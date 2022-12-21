# Fancy Software contracts

A collection of EVM smart contracts for the Fancy Software apps ecosystem.

## Contracts

### IPNFT721Soulbound

> Interplanetary Non-fungible File Token (721): Soulbound

Soulbound IPNFTs[^1] are bound to the owner's address and cannot be transferred.

### IPNFT1155Redeemable

> Interplanetary Non-fungible File Token (1155): Redeemable

Send minted IPNFTs[^1] back to the contract before they expire to redeem them.

### NFTFair

> Non-fungible Token Fair

A meta NFT marketplace without base fee.

### NFTHype

> Non-fungible Token Hype

A hype machine for NFTs.

## Development

1. Run Hardhat node with `pnpm run node`.
2. Deploy contracts with `pnpm run deploy -- --network localhost`.
   Copy the contracts' addresses into the application.

> NOTE: `hardhat.config.js` is a link to `hardhat.config.cjs` to make the HardHat VSCode extension happy.

## Deployment

1. Run `pnpm run deploy -- --network <network>`.

[^1]: https://github.com/nxsf/ipnft
