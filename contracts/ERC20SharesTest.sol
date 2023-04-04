// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20Shares, ERC20} from "./ERC20Shares.sol";

/**
 * @title ERC-20 Shares test contract
 * @author Fancy Software <fancysoft.eth>
 *
 * This contract implements share tokens for the Kawaiii™️ platform.
 */
contract ERC20SharesTest is ERC20Shares {
    constructor(uint256 cap) ERC20("ERC20SharesTest", "SHR") {
        _mint(msg.sender, cap);
    }
}
