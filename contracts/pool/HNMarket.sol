// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";
import "../token/interface/IHC.sol";

/**
 * @title HN Pool Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Stake HN to Harvest HC and Tokens
 */
contract HNPool is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

   /**
     * @param hnAddr Initialize HN Address
     * @param _tokenAddrs Initialize Tokens Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address[] memory _tokenAddrs,
        address receivingAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        tokenAddrs = _tokenAddrs;

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

}
