// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

/**
 * @title HN Pool Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HN Pool
 */
abstract contract IHNPool {
    mapping(address => mapping(uint256 => uint256)) public userStakes;

    function hnMarketWithdraw(
        address buyer,
        address seller,
        uint256 hnId
    ) external virtual;

    function getUserHnIdExistence(address user, uint256 hnId)
        external
        view
        virtual
        returns (bool);
}
