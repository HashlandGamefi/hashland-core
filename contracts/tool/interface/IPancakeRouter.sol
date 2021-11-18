// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface IPancakeRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}