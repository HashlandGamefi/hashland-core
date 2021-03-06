// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Upgrade Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can upgrade HN
 */
contract HNUpgrade is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
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
    uint256 public hashratesRange = 250;

    mapping(address => uint256) public userUpgradeCount;
    mapping(address => uint256) public userUpgradeAmount;

    EnumerableSet.AddressSet private users;

    event SetMaxLevel(uint256 level);
    event SetUpgradeBasePrice(uint256 price);
    event SetReceivingAddress(address receivingAddr);
    event SetDatas(
        uint256 hcBase,
        uint256 hcRange,
        uint256 hashratesBase,
        uint256 hashratesRange
    );
    event UpgradeHns(
        address indexed user,
        uint256 level,
        uint256 length,
        uint256[] hnIds
    );

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
     * @dev Set Max Level
     */
    function setMaxLevel(uint256 level) external onlyRole(MANAGER_ROLE) {
        maxLevel = level;

        emit SetMaxLevel(level);
    }

    /**
     * @dev Set Upgrade Base Price
     */
    function setUpgradeBasePrice(uint256 price)
        external
        onlyRole(MANAGER_ROLE)
    {
        upgradeBasePrice = price;

        emit SetUpgradeBasePrice(price);
    }

    /**
     * @dev Set Receiving Address
     */
    function setReceivingAddress(address receivingAddr)
        external
        onlyRole(MANAGER_ROLE)
    {
        receivingAddress = receivingAddr;

        emit SetReceivingAddress(receivingAddr);
    }

    /**
     * @dev Set Datas
     */
    function setDatas(
        uint256 _hcBase,
        uint256 _hcRange,
        uint256 _hashratesBase,
        uint256 _hashratesRange
    ) external onlyRole(MANAGER_ROLE) {
        hcBase = _hcBase;
        hcRange = _hcRange;
        hashratesBase = _hashratesBase;
        hashratesRange = _hashratesRange;

        emit SetDatas(_hcBase, _hcRange, _hashratesBase, _hashratesRange);
    }

    /**
     * @dev Upgrade
     */
    function upgrade(uint256[] calldata hnIds) external nonReentrant {
        require(hnIds.length > 0, "HnIds length must > 0");
        require(hnIds.length <= 256, "HnIds length must <= 256");
        require(hnIds.length % 4 == 0, "HnIds length % 4 must == 0");
        uint256 level = hn.level(hnIds[0]);
        require(level < maxLevel, "Hn level must < max Level");

        uint256 upgradePrice = getUpgradePrice(hnIds);
        hc.safeTransferFrom(msg.sender, receivingAddress, upgradePrice);

        uint256[] memory upgradedHnIds = new uint256[](hnIds.length / 4);
        for (uint256 index = 0; index < hnIds.length; index += 4) {
            uint256 hnId = hnIds[index];
            upgradedHnIds[index / 4] = hnId;
            uint256[] memory materialHnIds = new uint256[](3);
            materialHnIds[0] = hnIds[index + 1];
            materialHnIds[1] = hnIds[index + 2];
            materialHnIds[2] = hnIds[index + 3];

            require(hn.ownerOf(hnId) == msg.sender, "This Hn is not own");
            require(hn.level(hnId) == level, "Hn level mismatch");

            uint256[] memory hashrates = hn.getHashrates(hnId);
            uint256 class = hn.data(hnId, "class");
            class = class > 0 ? class : hn.getRandomNumber(hnId, "class", 1, 4);
            uint256 sameClassCount;
            for (uint256 i = 0; i < materialHnIds.length; i++) {
                require(
                    hn.ownerOf(materialHnIds[i]) == msg.sender,
                    "This Material Hn is not own"
                );
                require(
                    hn.level(materialHnIds[i]) == level,
                    "Material level mismatch"
                );

                hn.safeTransferFrom(
                    msg.sender,
                    receivingAddress,
                    materialHnIds[i]
                );

                uint256[] memory materialHashrates = hn.getHashrates(
                    materialHnIds[i]
                );
                for (uint256 j = 0; j < hashrates.length; j++) {
                    hashrates[j] += materialHashrates[j];
                }

                uint256 materialClass = hn.data(materialHnIds[i], "class");
                materialClass = materialClass > 0
                    ? materialClass
                    : hn.getRandomNumber(materialHnIds[i], "class", 1, 4);
                if (class == materialClass) sameClassCount++;
            }

            hn.setLevel(hnId, level + 1);

            for (uint256 i = 0; i < hashrates.length; i++) {
                uint256 randomness = uint256(
                    keccak256(
                        abi.encodePacked(
                            msg.sender,
                            block.number,
                            upgradePrice,
                            totalUpgradeCount,
                            userUpgradeCount[msg.sender],
                            hnId,
                            materialHnIds,
                            users.length(),
                            hashrates[i],
                            i
                        )
                    )
                );

                if (i == 0 && hashrates[i] == 0) {
                    hashrates[i] = hcBase + (randomness % hcRange);
                } else {
                    hashrates[i] =
                        (hashrates[i] *
                            (hcBase +
                                ((i == 0 ? level - 1 : level) * hashratesBase) +
                                (sameClassCount * hashratesRange) +
                                (randomness % hashratesRange))) /
                        hcBase;
                }
            }
            hn.setHashrates(hnId, hashrates);

            userUpgradeCount[msg.sender]++;
            totalUpgradeCount++;
        }

        userUpgradeAmount[msg.sender] += upgradePrice;
        totalUpgradeAmount += upgradePrice;
        users.add(msg.sender);

        emit UpgradeHns(msg.sender, level + 1, hnIds.length / 4, upgradedHnIds);
    }

    /**
     * @dev Get Users Length
     */
    function getUsersLength() external view returns (uint256) {
        return users.length();
    }

    /**
     * @dev Get Users by Size
     */
    function getUsersBySize(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory, uint256)
    {
        uint256 length = size;
        if (length > users.length() - cursor) {
            length = users.length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = users.at(cursor + i);
        }

        return (values, cursor + length);
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
