// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "@nxsf/ipnft/contracts/IPNFT1155.sol";

/**
 * @title Interplanetary Non-fungible File Token (1155): Redeemable
 * @author Fancy Software <fancysoft.eth>
 *
 * Send minted IPNFTs[^1] back to the contract before they expire to redeem them.
 *
 * [^1]: https://github.com/nxsf/ipnft
 */
contract IPNFT1155Redeemable is
    IPNFT1155,
    IERC1155Receiver,
    IERC2981,
    Multicall
{
    /// Emitted upon each minting.
    event Mint(uint256 indexed id, bool finalize, uint64 expiresAt);

    /// (ERC1155Supply) Total supply of a token.
    mapping(uint256 => uint256) private _totalSupply;

    /// A token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) private _royalty;

    /// Once a token is finalized, it cannot be minted anymore.
    mapping(uint256 => bool) public isFinalized;

    /// Get a redeemable token expiration timestamp.
    mapping(uint256 => uint64) public expiredAt;

    function claim(
        uint256 id,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset,
        uint8 royalty
    ) public {
        _claim(id, contentAuthor, content, contentCodec, ipftOffset);
        _royalty[id] = royalty;
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data,
        bool finalize,
        uint64 expiresAt
    ) public {
        require(to != address(this), "IPNFT1155Redeemable: mint to this");

        require(!isFinalized[id], "IPNFT1155Redeemable: finalized");
        isFinalized[id] = finalize;
        _updateExpiredAt(id, expiresAt);

        (IPNFT1155)._mint(to, id, amount, data);
        emit Mint(id, finalize, expiresAt);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data,
        bool finalize,
        uint64 expiresAt
    ) public {
        require(to != address(this), "IPNFT1155Redeemable: mint to this");

        for (uint256 i = 0; i < ids.length; i++) {
            require(!isFinalized[ids[i]], "IPNFT1155Redeemable: finalized");
            isFinalized[ids[i]] = finalize;
            _updateExpiredAt(ids[i], expiresAt);
        }

        (IPNFT1155)._mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            emit Mint(ids[i], finalize, expiresAt);
        }
    }

    /**
     * @dev (ERC1155Supply) Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev (ERC1155Supply) Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view returns (bool) {
        return totalSupply(id) > 0;
    }

    /**
     * Return true if a talent token has expired.
     */
    function hasExpired(uint256 tokenId) public view returns (bool) {
        return block.timestamp > expiredAt[tokenId];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * See {IERC2981-royaltyInfo}.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    )
        public
        view
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        return (
            contentAuthorOf(tokenId),
            (salePrice * _royalty[tokenId]) / type(uint8).max
        );
    }

    /**
     * Redeem a token by sending it to this contract.
     * See {IERC1155Receiver-onERC1155Received}.
     */
    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes calldata
    ) external view override(IERC1155Receiver) returns (bytes4) {
        require(
            msg.sender == address(this),
            "IPNFT1155Redeemable: not from this"
        );
        require(!hasExpired(id), "IPNFT1155Redeemable: expired");
        require(value > 0, "IPNFT1155Redeemable: zero value");
        return this.onERC1155Received.selector;
    }

    /**
     * Redeem a token batch by sending it to this contract.
     * See {IERC1155Receiver-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata
    ) external view override(IERC1155Receiver) returns (bytes4) {
        require(
            msg.sender == address(this),
            "IPNFT1155Redeemable: not from this"
        );
        require(
            ids.length == values.length,
            "IPNFT1155Redeemable: arg length mismatch"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            require(!hasExpired(ids[i]), "IPNFT1155Redeemable: expired");
            require(values[i] > 0, "IPNFT1155Redeemable: zero value");
        }

        return this.onERC1155BatchReceived.selector;
    }

    function _updateExpiredAt(uint256 id, uint64 expiresAt) internal {
        require(
            expiresAt >= expiredAt[id],
            "IPNFT1155Redeemable: expires earlier than before"
        );
        require(expiresAt > block.timestamp, "IPNFT1155Redeemable: expired");
        expiredAt[id] = expiresAt;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }
    }
}
