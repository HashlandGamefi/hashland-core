// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @title HNPool Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HNPool
 */
abstract contract IHNPool {
    mapping(address => mapping(uint256 => uint256)) public userStakes;

    function getUserHnIdExistence(address user, uint256 hnId)
        external
        view
        virtual
        returns (bool);
}
