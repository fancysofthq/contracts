// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Checkpoints
 * @author Fancy Software <fancysoft.eth>
 */
abstract contract Checkpoints {
    struct Checkpoint {
        uint milestone;
        uint value;
    }

    /**
     * Add or update the latest checkpoint with milestone and value.
     */
    function _checkpoint(
        Checkpoint[] storage checkpoints,
        uint milestone,
        uint value
    ) internal {
        if (checkpoints.length > 0) {
            Checkpoint storage latest = checkpoints[checkpoints.length - 1];

            if (latest.milestone == milestone) {
                latest.value = value;
                return;
            }
        }

        checkpoints.push(Checkpoint({milestone: milestone, value: value}));
    }

    /**
     * Given the list of checkpoints, return the value of the latest checkpoint with milestone
     * less than or equal to `milestone`, or zero if there is no such checkpoint.
     */
    function _latestCheckpointValue(
        Checkpoint[] storage checkpoints,
        uint milestone
    ) internal view returns (uint) {
        if (checkpoints.length == 0) {
            return 0; // No value at the moment of the milestone
        }

        Checkpoint storage checkpoint = checkpoints[
            _latestCheckpointIndex(checkpoints, milestone)
        ];

        if (checkpoint.milestone > milestone) {
            return 0; // No value at the moment of the milestone
        }

        return checkpoint.value;
    }

    /**
     * Given the list of checkpoints, return the index of the latest checkpoint with milestone
     * less than or equal to `milestone`, or zero if there is no such checkpoint.
     */
    function _latestCheckpointIndex(
        Checkpoint[] storage checkpoints,
        uint milestone
    ) internal view returns (uint) {
        if (checkpoints.length == 0) {
            return 0;
        }

        uint low = 0;
        uint high = checkpoints.length - 1;

        while (low < high) {
            uint mid = (low + high + 1) / 2;

            if (checkpoints[mid].milestone <= milestone) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        return low;
    }
}
