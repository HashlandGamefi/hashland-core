// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title HC Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HC
 */
interface IHC is IERC20 {
    function mint(address poolAddr) external;

    function getPoolHCReward(address poolAddr) external view returns (uint256);
}
