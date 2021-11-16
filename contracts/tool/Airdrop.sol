// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../token/interface/IHN.sol";

/**
 * @title Airdrop
 * @author HASHLAND-TEAM
 * @notice You can use this contract to airdrop tokens and NFTs
 */
contract Airdrop {
    using SafeERC20 for IERC20;

    constructor() {}

    /**
     * @dev Airdrop Tokens
     */
    function airdropTokens(
        address tokenAddr,
        address[] calldata to,
        uint256[] calldata amount
    ) external {
        require(to.length == amount.length, "Data length does not match");
        for (uint256 i = 0; i < to.length; i++) {
            IERC20(tokenAddr).safeTransferFrom(msg.sender, to[i], amount[i]);
        }
    }

    /**
     * @dev Airdrop NFTs
     */
    function airdropNFTs(
        address nftAddr,
        address[] calldata to,
        uint256[] calldata amount
    ) external {
        require(to.length == amount.length, "Data length does not match");
        for (uint256 i = 0; i < to.length; i++) {
            uint256[] memory hnIds = new uint256[](amount[i]);
            (hnIds, ) = IHN(nftAddr).tokensOfOwnerBySize(
                msg.sender,
                0,
                amount[i]
            );
            IHN(nftAddr).safeTransferFromBatch(msg.sender, to[i], hnIds);
        }
    }
}
