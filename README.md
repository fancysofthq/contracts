# Fancy Software contracts

A collection of EVM smart contracts for the Fancy Software apps ecosystem.

## Contracts

### IPNFT721Soulbound

> Interplanetary Non-fungible File Token (721): Soulbound

Soulbound IPNFTs[^1] are bound to the owner's address and cannot be transferred.

### IPNFT1155Redeemable

> Interplanetary Non-fungible File Token (1155): Redeemable

Send minted IPNFTs[^1] back to the contract before they expire to redeem them.

### NFTMarketplace

> Non-fungible Token Marketplace

A meta NFT marketplace contract without base fee.

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

### Known deployments

#### Polygon Mumbai

```
NFTFair deployed to 0x51fd09Bf2059Cfc88C508A41866087E1ba0EBBf7
Tx 0x38272069b6aad11592c53f4ccaf59428cfee345805012bd2d978ac5b0d374ab8

NFTHype deployed to 0x38699A7e76805379c6D46EC447C263B389673bAf
Tx 0xe57da0fbee7d03ea2a11ae662551e657b05ec0eff1bf28932d30163af43b553d
```

[^1]: https://github.com/nxsf/ipnft
