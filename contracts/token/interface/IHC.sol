// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title HC Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HC
 */
interface IHC is IERC20 {
    function harvestToken() external returns (uint256);

    function getTokenRewards(address poolAddr) external view returns (uint256);
}
