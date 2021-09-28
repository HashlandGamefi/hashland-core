// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Upgrade Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Upgrade HN
 */
contract HNUpgrade is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public hc;
    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public receivingAddress;
    uint256 public upgradePrice = 10e18;
    uint256 public totalUpgradeCount;
    uint256 public totalUpgradeAmount;

    uint256 public itemsLength = 20;

    mapping(uint256 => uint256) public upgradedLevels;
    mapping(address => uint256) public userUpgradeCount;
    mapping(address => uint256) public userUpgradeAmount;

    EnumerableSet.AddressSet private users;

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
     * @dev Withdraw NFT
     */
    function withdrawNFT(
        address nftAddr,
        address to,
        uint256 tokenId
    ) external onlyRole(MANAGER_ROLE) {
        IERC721Enumerable nft = IERC721Enumerable(nftAddr);
        nft.safeTransferFrom(address(this), to, tokenId);
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
     * @dev Set Datas
     */
    function setDatas(uint256 _itemsLength) external onlyRole(MANAGER_ROLE) {
        itemsLength = _itemsLength;
    }

    /**
     * @dev Upgrade
     */
    function upgrade(uint256 hnId, uint256[] calldata materialHnIds) external {
        require(hn.ownerOf(hnId) == msg.sender, "This Hn is not Own");
        require(materialHnIds.length == 3, "Material Length must == 3");
        uint256 level = hn.level(hnId);
        require(level < 5, "Hn Level must < 5");

        hc.transferFrom(msg.sender, receivingAddress, upgradePrice);
        uint256[] memory hashrates = hn.getHashrates(hnId);
        uint256[] memory attrs = hn.getDatas(hnId, "attrs");
        uint256[] memory items = hn.getDatas(hnId, "items");
        for (uint256 i = 0; i < materialHnIds.length; i++) {
            require(
                hn.level(materialHnIds[i]) == level,
                "Material Level Mismatch"
            );

            hn.safeTransferFrom(msg.sender, address(this), materialHnIds[i]);

            uint256[] memory materialHashrates = hn.getHashrates(
                materialHnIds[i]
            );
            hashrates[0] += materialHashrates[0];
            hashrates[1] += materialHashrates[1];

            uint256[] memory materialAttrs = hn.getDatas(
                materialHnIds[i],
                "attrs"
            );
            for (uint256 j = 0; j < 6; j++) {
                attrs[j] += materialAttrs[j];
            }
        }

        hn.setLevel(hnId, level + 1);
        hn.setHashrates(hnId, hashrates);
        hn.setDatas(hnId, "attrs", attrs);

        uint256 randomness = uint256(
            keccak256(
                abi.encodePacked(
                    upgradePrice,
                    totalUpgradeCount,
                    totalUpgradeAmount,
                    upgradedLevels[hnId],
                    userUpgradeCount[msg.sender],
                    userUpgradeAmount[msg.sender],
                    hnId,
                    materialHnIds,
                    users.length(),
                    msg.sender,
                    block.timestamp
                )
            )
        );
        uint256[] memory newItems = new uint256[](items.length + 1);
        for (uint256 i = 0; i < items.length; i++) {
            newItems[i] = items[i];
        }
        newItems[items.length] = ((randomness % 1e2) % itemsLength) + 1;
        hn.setDatas(hnId, "items", newItems);

        totalUpgradeCount++;
        totalUpgradeAmount += upgradePrice;
        userUpgradeCount[msg.sender]++;
        userUpgradeAmount[msg.sender] += upgradePrice;
        upgradedLevels[hnId]++;
        users.add(msg.sender);

        emit UpgradeHn(msg.sender, hnId);
    }

    /**
     * @dev Get Users Length
     */
    function getUsersLength() external view returns (uint256) {
        return users.length();
    }

    /**
     * @dev Get User by Index
     */
    function getUserByIndex(uint256 index) external view returns (address) {
        return users.at(index);
    }

    /**
     * @dev Get Users
     */
    function getUsers() external view returns (address[] memory) {
        return users.values();
    }
}
