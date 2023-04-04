// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Shares
 * @author Fancy Software <fancysoft.eth>
 *
 * Shareholders of this contract receive a portion of all native token value sent to it.
 *
 * The share is determined by {getPastShares} at the end of the block containing a receive.
 *
 * Dividends can be harvested by calling {harvestBatch}.
 * A shareholder can {setHarvestPremium}, default to 0.
 */
abstract contract Shares {
    /**
     * Emitted when native token is received.
     */
    event Income(uint value);

    /**
     * Emitted when dividends are harvested.
     */
    event HarvestBatch(
        address indexed harvester,
        address indexed account,
        uint[] blockNumbers,
        uint totalDividends,
        uint totalPremium
    );

    /// @dev (blockNumber => value).
    mapping(uint => uint) _incomeByBlock;

    /// @dev (account => (blockNumber => alreadyHarvested)).
    mapping(address => mapping(uint => bool)) private _alreadyHarvested;

    /// @dev (account => harvestPremium).
    mapping(address => uint8) private _harvestPremium;

    receive() external payable virtual {
        _incomeByBlock[block.number] += msg.value;
        emit Income(msg.value);
    }

    /**
     * Set harvest premium base (0-255) for the caller.
     */
    function setHarvestPremium(uint8 premium) external {
        _harvestPremium[msg.sender] = premium;
    }

    /**
     * Harvest dividends from multiple blocks for an account.
     *
     * Requirements:
     *
     * - Each block must yield dividends for the account.
     *
     */
    function harvestBatch(
        address account,
        uint[] calldata blockNumbers
    ) external {
        uint totalDividends = 0;
        uint totalPremium = 0;

        for (uint i = 0; i < blockNumbers.length; i++) {
            uint blockNumber = blockNumbers[i];

            require(
                !_alreadyHarvested[account][blockNumber],
                "Shares: already harvested"
            );
            _alreadyHarvested[account][blockNumber] = true;

            uint income = _incomeByBlock[blockNumber];
            require(income > 0, "Shares: no dividends to harvest (a)");

            uint balance = getPastShares(account, blockNumber);
            require(balance > 0, "Shares: no dividends to harvest (b)");

            uint totalSupply = getPastTotalShares(blockNumber);
            require(totalSupply > 0, "Shares: no dividends to harvest (c)");

            uint dividend = (income * balance) / totalSupply;

            if (msg.sender != account) {
                uint premium = (dividend * getHarvestPremium(account)) /
                    type(uint8).max;

                if (premium > 0) {
                    totalPremium += premium;

                    unchecked {
                        dividend -= premium;
                    }
                }
            }

            totalDividends += dividend;
        }

        if (totalPremium > 0) {
            require(
                payable(msg.sender).send(totalPremium),
                "Shares: failed to send harvest premium"
            );
        }

        require(
            payable(account).send(totalDividends),
            "Shares: failed to send dividends"
        );

        emit HarvestBatch(
            msg.sender,
            account,
            blockNumbers,
            totalDividends,
            totalPremium
        );
    }

    /**
     * Get past shares for an account.
     */
    function getPastShares(
        address account,
        uint blockNumber
    ) public view virtual returns (uint);

    /**
     * Get past total shares.
     */
    function getPastTotalShares(
        uint blockNumber
    ) public view virtual returns (uint);

    /**
     * Get harvest premium base (0-255) for an account.
     */
    function getHarvestPremium(address account) public view returns (uint8) {
        return _harvestPremium[account];
    }
}
