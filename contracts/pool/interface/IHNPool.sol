// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

/**
 * @title HN Pool Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HN Pool
 */
abstract contract IHNPool {
    mapping(address => mapping(uint256 => uint256)) public userStakes;

    function getUserHnIdExistence(address user, uint256 hnId)
        external
        view
        virtual
        returns (bool);
}
