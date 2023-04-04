// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Checkpoints, ERC20} from "./ERC20Checkpoints.sol";
import {Shares} from "./Shares.sol";

/**
 * @title ERC-20 Shares
 * @author Fancy Software <fancysoft.eth>
 * @notice This contract implements {Shares} for ERC-20 tokens by extending {ERC20Checkpoints},
 * where a checkpoint milestone is a block at which native token value is received.
 */
abstract contract ERC20Shares is ERC20Checkpoints, Shares {
    /// @dev A checkpoint milestone is the block at which native token value is received.
    uint[] private _receiveBlockNumbers;

    receive() external payable override(Shares) {
        Shares._incomeByBlock[block.number] += msg.value;

        if (
            _receiveBlockNumbers.length == 0 ||
            _receiveBlockNumbers[_receiveBlockNumbers.length - 1] !=
            block.number
        ) {
            _receiveBlockNumbers.push(block.number);
        }

        emit Shares.Income(msg.value);
    }

    function getPastShares(
        address account,
        uint blockNumber
    ) public view override(Shares) returns (uint) {
        return balanceOfAt(account, blockNumber);
    }

    function getPastTotalShares(
        uint blockNumber
    ) public view override(Shares) returns (uint) {
        return totalSupplyAt(blockNumber);
    }

    function _getCurrentMilestone()
        internal
        view
        override(ERC20Checkpoints)
        returns (uint)
    {
        return
            _receiveBlockNumbers.length > 0
                ? _receiveBlockNumbers[_receiveBlockNumbers.length - 1]
                : 0;
    }
}
