// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

/**
 * @title HN Market Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HN Market
 */
interface IHNMarket {
    function hnPoolCancel(address seller, uint256[] calldata _hnIds) external;
}
