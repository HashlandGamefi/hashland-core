// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title Hashland Coin
 * @author HASHLAND-TEAM
 * @notice This Contract Supply HC
 */
contract HC is ERC20, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @param minter Initialize Minter Role
     */
    constructor(address minter) ERC20("Hashland Coin", "HC") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Create New Tokens to an Address
     */
    function mint(address receiver, uint256 tokens)
        external
        onlyRole(MINTER_ROLE)
    {
        _mint(receiver, tokens);
    }
}
