// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Checkpoints} from "./Checkpoints.sol";

/**
 * @title ERC-20 Checkpoints
 * @author Fancy Software <fancysoft.eth>
 *
 * An ERC-20 implementation with checkpointed balances and total supply.
 *
 * @notice It's up to the implementor to decide what is considered a milestone.
 * See {_getCurrentMilestone} for more details.
 */
abstract contract ERC20Checkpoints is ERC20, Checkpoints {
    mapping(address => Checkpoint[]) private _balanceCheckpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    /**
     * Get an account balance by the blockNumber.
     */
    function balanceOfAt(
        address account,
        uint blockNumber
    ) public view returns (uint) {
        return
            _latestCheckpointValue(
                _balanceCheckpoints[account],
                blockNumber - 1
            );
    }

    /**
     * Get the total supply by the blockNumber.
     */
    function totalSupplyAt(uint blockNumber) public view returns (uint) {
        return
            _latestCheckpointValue(_totalSupplyCheckpoints, blockNumber - 1);
    }

    /**
     * Get the current milestone.
     *
     * @dev This function is called by {_afterTokenTransfer} to determine the current milestone.
     * For example, if it is set to the current block number, then a new checkpoint is be created on every transfer.
     * If the milestone value change is less common, a checkpoint is updated instead of adding a new one.
     */
    function _getCurrentMilestone() internal view virtual returns (uint);

    function _afterTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        uint milestone = _getCurrentMilestone();

        if (from == address(0) || to == address(0)) {
            _checkpoint(_totalSupplyCheckpoints, milestone, totalSupply());
        }

        if (from != address(0)) {
            _checkpoint(_balanceCheckpoints[from], milestone, balanceOf(from));
        }

        if (to != address(0)) {
            _checkpoint(_balanceCheckpoints[to], milestone, balanceOf(to));
        }
    }
}
