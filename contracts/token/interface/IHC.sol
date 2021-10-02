// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title HC Token Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HC Token
 */
interface IHC is IERC20 {
    function mint(address receiver, uint256 tokens) external;
}
