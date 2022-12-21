// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT Hype
 * @author Fancy Software <fancysoft.eth>
 *
 * A hype machine for NFTs.
 */
contract NFTHype {
    struct Token {
        address contractAddress;
        uint256 tokenId;
    }

    /// Hype.
    event Hype(
        address operator,
        address indexed app,
        Token token,
        Token indexed tokenIndex,
        uint256 value,
        bytes hypedata
    );

    function hype(
        address app,
        Token calldata token,
        bytes calldata hypedata
    ) public payable {
        if (msg.value > 0) {
            (bool success, ) = app.call{value: msg.value}("");
            require(success, "Hype: failed to pay");
        }

        emit Hype(msg.sender, app, token, token, msg.value, hypedata);
    }
}
