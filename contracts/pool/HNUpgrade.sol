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
    uint256 public maxLevel = 5;
    uint256 public upgradeBasePrice = 4;
    uint256 public totalUpgradeCount;
    uint256 public totalUpgradeAmount;

    uint256 public hcBase = 10000;
    uint256 public hcRange = 1000;

    uint256 public hashratesBase = 1000;
    uint256 public hashratesRange = 1000;

    uint256 public itemsBase = 1;
    uint256 public itemsRange = 20;

    mapping(uint256 => uint256) public upgradedLevels;
    mapping(address => uint256) public userUpgradeCount;
    mapping(address => uint256) public userUpgradeAmount;

    EnumerableSet.AddressSet private users;

    event UpgradeHn(address user, uint256[] hnIds);

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
     * @dev Set Max Level
     */
    function setMaxLevel(uint256 level) external onlyRole(MANAGER_ROLE) {
        maxLevel = level;
    }

    /**
     * @dev Set Upgrade Base Price
     */
    function setUpgradeBasePrice(uint256 price)
        external
        onlyRole(MANAGER_ROLE)
    {
        upgradeBasePrice = price;
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
    function setDatas(
        uint256 _hcBase,
        uint256 _hcRange,
        uint256 _hashratesBase,
        uint256 _hashratesRange,
        uint256 _itemsBase,
        uint256 _itemsRange
    ) external onlyRole(MANAGER_ROLE) {
        hcBase = _hcBase;
        hcRange = _hcRange;
        hashratesBase = _hashratesBase;
        hashratesRange = _hashratesRange;
        itemsBase = _itemsBase;
        itemsRange = _itemsRange;
    }

    /**
     * @dev Upgrade
     */
    function upgrade(uint256[] calldata hnIds) external {
        require(hnIds.length > 0, "HnIds Length must > 0");
        require(hnIds.length <= 100, "HnIds Length must <= 100");
        require(hnIds.length % 4 == 0, "HnIds Length % 4 must == 0");
        uint256 level = hn.level(hnIds[0]);
        require(level < maxLevel, "Hn Level must < Max Level");

        uint256 upgradePrice = getUpgradePrice(hnIds);
        hc.transferFrom(msg.sender, receivingAddress, upgradePrice);

        for (uint256 index = 0; index < hnIds.length; index += 4) {
            uint256 hnId = hnIds[index];
            uint256[] memory materialHnIds = new uint256[](3);
            materialHnIds[0] = hnIds[index + 1];
            materialHnIds[1] = hnIds[index + 2];
            materialHnIds[2] = hnIds[index + 3];

            require(hn.ownerOf(hnId) == msg.sender, "This Hn is not Own");
            require(hn.level(hnId) == level, "Hn Level Mismatch");

            uint256[] memory hashrates = hn.getHashrates(hnId);
            uint256[] memory attrs = hn.getDatas(hnId, "attrs");
            uint256[] memory items = hn.getDatas(hnId, "items");
            for (uint256 i = 0; i < materialHnIds.length; i++) {
                require(
                    hn.level(materialHnIds[i]) == level,
                    "Material Level Mismatch"
                );

                hn.safeTransferFrom(
                    msg.sender,
                    address(this),
                    materialHnIds[i]
                );

                uint256[] memory materialHashrates = hn.getHashrates(
                    materialHnIds[i]
                );
                for (uint256 j = 0; j < hashrates.length; j++) {
                    hashrates[j] += materialHashrates[j];
                }

                uint256[] memory materialAttrs = hn.getDatas(
                    materialHnIds[i],
                    "attrs"
                );
                for (uint256 j = 0; j < attrs.length; j++) {
                    attrs[j] += materialAttrs[j];
                }
            }

            hn.setLevel(hnId, level + 1);
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

            for (uint256 i = 0; i < hashrates.length; i++) {
                uint256 random = uint256(
                    keccak256(abi.encodePacked(randomness, hashrates, i))
                );
                if (i == 0 && hashrates[i] == 0) {
                    hashrates[i] = hcBase + (random % hcRange);
                } else {
                    hashrates[i] =
                        (hashrates[i] *
                            (hcBase +
                                level *
                                hashratesBase +
                                (random % hashratesRange))) /
                        hcBase;
                }
            }
            hn.setHashrates(hnId, hashrates);

            uint256[] memory newItems = new uint256[](items.length + 1);
            for (uint256 i = 0; i < items.length; i++) {
                newItems[i] = items[i];
            }
            newItems[items.length] = itemsBase + (randomness % itemsRange);
            hn.setDatas(hnId, "items", newItems);

            upgradedLevels[hnId]++;
            userUpgradeCount[msg.sender]++;
            totalUpgradeCount++;
        }

        userUpgradeAmount[msg.sender] += upgradePrice;
        totalUpgradeAmount += upgradePrice;
        users.add(msg.sender);

        emit UpgradeHn(msg.sender, hnIds);
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

    /**
     * @dev Get Upgrade Price
     */
    function getUpgradePrice(uint256[] calldata hnIds)
        public
        view
        returns (uint256)
    {
        uint256 level = hn.level(hnIds[0]);
        return upgradeBasePrice**level * 1e18 * (hnIds.length / 4);
    }
}
