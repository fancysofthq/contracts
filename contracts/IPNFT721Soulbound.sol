// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@nxsf/ipnft/contracts/IPNFT721.sol";

/**
 * @title Interplanetary Non-fungible File Token (721): Soulbound
 * @author Fancy Software <fancysoft.eth>
 *
 * Soulbound IPNFTs[^1] are bound to the owner's address and cannot be transferred.
 *
 * [^1]: https://github.com/nxsf/ipnft
 */
contract IPNFT721Soulbound is IPNFT721, Ownable {
    event Soulbound(uint256 indexed tokenId, address soul);

    mapping(uint256 => bool) public isSoulbound;

    constructor(
        string memory name,
        string memory symbol
    ) IPNFT721(name, symbol) {}

    /**
     * @param soulbound If set, the token is soulbound to `to`.
     * Otherwise, the token is soulbound to the next owner.
     */
    function mint(
        address to,
        uint256 id,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset,
        bool soulbound
    ) public {
        (IPNFT721)._mint(
            to,
            id,
            contentAuthor,
            content,
            contentCodec,
            ipftOffset
        );

        if (soulbound) {
            isSoulbound[id] = soulbound;
            emit Soulbound(id, to);
        }
    }

    function burn(uint256 id) public {
        require(
            ownerOf(id) == msg.sender ||
                isApprovedForAll(ownerOf(id), msg.sender),
            "IPNFT721Soulbound: unauthorized"
        );

        _burn(id);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        if (from != address(0) && to != address(0)) {
            require(!isSoulbound[tokenId], "IPNFT721Soulbound: soulbound");
            isSoulbound[tokenId] = true;
            emit Soulbound(tokenId, to);
        }

        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
