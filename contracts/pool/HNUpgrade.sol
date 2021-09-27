// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Upgrade Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Upgrade HN
 */
contract HNUpgrade is ERC721Holder, AccessControlEnumerable {
    IERC20 public hc;
    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public receivingAddress;
    uint256 public upgradePrice = 10e18;

    mapping(uint256 => uint256) public upgradedLevels;

    event UpgradeHn(address user, uint256 hnId);

    /**
     * @param hcAddr Initialize HC Address
     * @param hnAddr Initialize HN Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hcAddr,
        address hnAddr,
        address receivingAddr,
        address manager
    ) {
        hc = IERC20(hcAddr);
        hn = IHN(hnAddr);

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Withdraw Token
     */
    function withdrawToken(
        address tokenAddr,
        address to,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        IERC20 token = IERC20(tokenAddr);
        token.transfer(to, amount);
    }

    /**
     * @dev Set Upgrade Price
     */
    function setUpgradePrice(uint256 _upgradePrice)
        external
        onlyRole(MANAGER_ROLE)
    {
        upgradePrice = _upgradePrice;
    }

    /**
     * @dev Set Receiving Address
     */
    function setReceivingAddress(address receivingAddr)
        external
        onlyRole(MANAGER_ROLE)
    {
        receivingAddress = receivingAddr;
    }

    /**
     * @dev Upgrade
     */
    function upgrade(uint256 hnId, uint256[] calldata materialHnIds) external {
        require(hn.ownerOf(hnId) == msg.sender, "This Hn is not Own");
        require(materialHnIds.length == 3, "Material Length must == 3");
        uint256 level = hn.level(hnId);
        for (uint256 i = 0; i < materialHnIds.length; i++) {
            require(hn.level(materialHnIds[i]) == level, "Material Level Mismatch");
            hn.safeTransferFrom(msg.sender, address(this), materialHnIds[i]);
        }
        hc.transferFrom(msg.sender, receivingAddress, upgradePrice);

        hn.setLevel(hnId, level + 1);
        upgradedLevels[hnId]++;

        emit UpgradeHn(msg.sender, hnId);
    }
}
