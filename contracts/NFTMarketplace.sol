// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

// TODO: Operator approvals.
// TODO: Seller approvals, primary & secondary listings.
// TODO: Fungible (ERC777) tokens.
/**
 * @title NFT Marketplace
 * @author Fancy Software <fancysoft.eth>
 *
 * A meta NFT marketplace contract without base fee.
 */
contract NFTMarketplace is IERC721Receiver, IERC1155Receiver {
    struct Token {
        address contractAddress;
        uint256 tokenId;
    }
    struct ListingConfig {
        address app;
        address seller;
        uint256 price;
    }
    struct Listing {
        ListingConfig config;
        Token token;
        uint256 stockSize;
    }

    event SetAppFee(address indexed app, uint8 fee);
    event List(
        address operator,
        address indexed app,
        bytes32 listingId,
        Token token,
        Token indexed tokenIndex,
        address indexed seller,
        uint256 price,
        uint256 stockSize
    );
    event SetPrice(
        address operator,
        address indexed app,
        bytes32 indexed listingId,
        uint256 price
    );
    event Replenish(
        address operator,
        address indexed app,
        bytes32 indexed listingId,
        uint256 amount
    );
    event Withdraw(
        address operator,
        address indexed app,
        bytes32 indexed listingId,
        uint256 amount,
        address to
    );
    event Purchase(
        address operator,
        address indexed app,
        bytes32 indexed listingId,
        address indexed buyer,
        uint256 tokenAmount,
        address sendTo,
        uint256 income,
        address royaltyAddress,
        uint256 royaltyValue,
        uint256 appFee,
        uint256 sellerProfit
    );

    mapping(address => uint8) public getAppFee;
    mapping(bytes32 => Listing) public getListing;

    modifier onlyAppOwner(address app) {
        require(msg.sender == app, "NFTMarketplace: not app owner");
        _;
    }

    /**
     * Set application fee.
     */
    function setAppFee(address app, uint8 fee) public onlyAppOwner(app) {
        require(getAppFee[app] != fee, "NFTMarketplace: already set");
        getAppFee[app] = fee;
        emit SetAppFee(app, fee);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        ListingConfig memory config = abi.decode(data, (ListingConfig));
        _checkConfig(config);
        require(
            (config.seller == from || config.seller == operator),
            "NFTMarketplace: invalid seller"
        );

        _processListing(operator, config, Token(msg.sender, tokenId), 1);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 tokenId,
        uint256 tokenValue,
        bytes calldata data
    ) external override returns (bytes4) {
        ListingConfig memory config = abi.decode(data, (ListingConfig));
        _checkConfig(config);
        require(
            (config.seller == from || config.seller == operator),
            "NFTMarketplace: invalid seller"
        );

        _processListing(
            operator,
            config,
            Token(msg.sender, tokenId),
            tokenValue
        );

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenValues,
        bytes calldata data
    ) external override returns (bytes4) {
        ListingConfig memory config = abi.decode(data, (ListingConfig));
        _checkConfig(config);
        require(
            config.seller == from || config.seller == operator,
            "NFTMarketplace: invalid seller"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _processListing(
                operator,
                config,
                Token(msg.sender, tokenIds[i]),
                tokenValues[i]
            );
        }

        return this.onERC1155BatchReceived.selector;
    }

    function setListingPrice(bytes32 listingId, uint256 newPrice) public {
        Listing storage listing = getListing[listingId];

        require(
            msg.sender == listing.config.seller,
            "NFTMarketplace: unauthorized"
        );
        require(
            listing.config.price != newPrice,
            "NFTMarketplace: already set"
        );

        listing.config.price = newPrice;

        emit SetPrice(msg.sender, listing.config.app, listingId, newPrice);
    }

    function withdraw(bytes32 listingId, uint256 amount, address to) external {
        Listing storage listing = getListing[listingId];

        require(
            msg.sender == listing.config.seller,
            "NFTMarketplace: unauthorized"
        );
        require(
            listing.stockSize >= amount,
            "NFTMarketplace: not enough stock"
        );

        unchecked {
            listing.stockSize -= amount;
        }

        if (
            _isInterface(
                address(listing.token.contractAddress),
                type(IERC721).interfaceId
            )
        ) {
            IERC721(listing.token.contractAddress).safeTransferFrom(
                address(this),
                to,
                listing.token.tokenId,
                ""
            );
        } else if (
            _isInterface(
                address(listing.token.contractAddress),
                type(IERC1155).interfaceId
            )
        ) {
            IERC1155(listing.token.contractAddress).safeTransferFrom(
                address(this),
                to,
                listing.token.tokenId,
                amount,
                ""
            );
        }

        emit Withdraw(
            msg.sender,
            getListing[listingId].config.app,
            listingId,
            amount,
            to
        );
    }

    function purchase(
        bytes32 listingId,
        uint256 amount,
        address sendTo
    ) external payable {
        Listing storage listing = getListing[listingId];

        require(amount > 0, "NFTMarketplace: amount must be positive");
        require(
            listing.stockSize >= amount,
            "NFTMarketplace: insufficient stock"
        );

        require(
            listing.config.price * amount == msg.value,
            "NFTMarketplace: invalid value"
        );

        unchecked {
            listing.stockSize -= amount;
        }

        uint256 income = msg.value;
        uint256 profit = income;
        address royaltyAddress;
        uint256 royaltyValue;
        uint256 appFee_;

        // Royalties are top priority for healthy economy.
        if (
            _isInterface(
                address(listing.token.contractAddress),
                type(IERC2981).interfaceId
            )
        ) {
            (royaltyAddress, royaltyValue) = IERC2981(
                address(listing.token.contractAddress)
            ).royaltyInfo(listing.token.tokenId, profit);

            if (royaltyAddress != listing.config.seller && royaltyValue > 0) {
                profit -= royaltyValue;
                (bool ok, ) = royaltyAddress.call{value: royaltyValue}("");
                require(ok, "NFTMarketplace: failed to send royalty");
            }
        }

        // Then, transfer the base & application fees.
        if (profit > 0 && getAppFee[listing.config.app] > 0) {
            appFee_ =
                (profit * getAppFee[listing.config.app]) /
                type(uint8).max;

            if (appFee_ > 0) {
                unchecked {
                    profit -= appFee_;
                }

                (bool ok, ) = listing.config.app.call{value: appFee_}("");
                require(ok, "NFTMarketplace: failed to send app fee");
            }
        }

        // Transfer what's left to the seller.
        if (profit > 0) {
            (bool ok, ) = listing.config.seller.call{value: profit}("");
            require(ok, "NFTMarketplace: failed to send profit");
        }

        // Then transfer the token(s) to the buyer.
        if (
            _isInterface(
                address(listing.token.contractAddress),
                type(IERC721).interfaceId
            )
        ) {
            IERC721(listing.token.contractAddress).safeTransferFrom(
                address(this),
                sendTo,
                listing.token.tokenId,
                ""
            );
        } else if (
            _isInterface(
                address(listing.token.contractAddress),
                type(IERC1155).interfaceId
            )
        ) {
            IERC1155(listing.token.contractAddress).safeTransferFrom(
                address(this),
                sendTo,
                listing.token.tokenId,
                amount,
                ""
            );
        }

        // Finally, emit the event.
        emit Purchase(
            msg.sender,
            listing.config.app,
            listingId,
            msg.sender,
            amount,
            sendTo,
            income,
            royaltyAddress,
            royaltyValue,
            appFee_,
            profit
        );
    }

    function listingExists(bytes32 listingId) public view returns (bool) {
        return getListing[listingId].config.app != address(0);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function getListingId(
        address app,
        Token memory token,
        address seller
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    app,
                    token.contractAddress,
                    token.tokenId,
                    seller
                )
            );
    }

    function _processListing(
        address operator,
        ListingConfig memory config,
        Token memory token,
        uint256 value
    ) internal {
        bytes32 listingId = getListingId(config.app, token, config.seller);

        if (!listingExists(listingId)) {
            getListing[listingId].config = config;
            getListing[listingId].token = token;
            getListing[listingId].stockSize = value;

            emit List(
                operator,
                config.app,
                listingId,
                token,
                token,
                config.seller,
                config.price,
                value
            );
        } else {
            if (getListing[listingId].config.price != config.price) {
                getListing[listingId].config.price = config.price;

                emit SetPrice(operator, config.app, listingId, config.price);
            }

            getListing[listingId].stockSize += value;
            emit Replenish(operator, config.app, listingId, value);
        }
    }

    function _checkConfig(ListingConfig memory config) internal pure {
        require(config.app != address(0), "NFTMarketplace: invalid app");
        require(config.price > 0, "NFTMarketplace: invalid price");
        require(config.seller != address(0), "NFTMarketplace: invalid seller");
    }

    function _isInterface(
        address contract_,
        bytes4 interfaceId
    ) internal view returns (bool) {
        return IERC165(contract_).supportsInterface(interfaceId);
    }
}
