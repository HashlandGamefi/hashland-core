// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

/**
 * @title Invite Pool Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the Invite Pool
 */
interface IInvitePool {
    function depositInviter(address user, uint256 hashrate) external;

    function withdrawInviter(address user, uint256 hashrate) external;
}
