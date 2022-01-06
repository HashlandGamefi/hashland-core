// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Upgrade Contract V2
 * @author HASHLAND-TEAM
 * @notice In this contract users can upgrade HN
 */
contract HNUpgradeV2 is
    AccessControlEnumerable,
    VRFConsumerBase,
    ReentrancyGuard
{
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

    bool public vrfFlag = true;
    uint256 public ultraRate = 100;
    uint256 public crossRate = 100;

    uint256 public hcBase = 10000;
    uint256 public hcRange = 1000;

    uint256 public hashratesBase = 1000;
    uint256 public hashratesRange = 250;

    mapping(address => uint256) public userUpgradeCount;
    mapping(address => uint256) public userUpgradeAmount;

    EnumerableSet.AddressSet private users;

    mapping(bytes32 => address) public requestIdToUser;
    mapping(bytes32 => uint256) public requestIdToLevel;
    mapping(bytes32 => uint256[]) public requestIdToUpgradedHnIds;
    mapping(bytes32 => uint256[][]) public requestIdToUpgradedHashrates;
    mapping(bytes32 => uint256[]) public requestIdToSameClassCounts;

    bytes32 public keyHash;
    uint256 public fee;

    event SetMaxLevel(uint256 level);
    event SetUpgradeBasePrice(uint256 price);
    event SetReceivingAddress(address receivingAddr);
    event SetDatas(
        bool vrfFlag,
        uint256 ultraRate,
        uint256 crossRate,
        uint256 hcBase,
        uint256 hcRange,
        uint256 hashratesBase,
        uint256 hashratesRange
    );
    event Upgrade(address indexed user, uint256 level, uint256 length);
    event UpgradeHns(
        address indexed user,
        uint256[] levels,
        uint256 length,
        uint256[] hnIds,
        bool[] ultras
    );

    /**
     * @param vrfAddr Initialize VRF Coordinator Address
     * @param linkAddr Initialize LINK Token Address
     * @param _keyHash Initialize Key Hash
     * @param _fee Initialize Fee
     * @param hcAddr Initialize HC Address
     * @param hnAddr Initialize HN Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address vrfAddr,
        address linkAddr,
        bytes32 _keyHash,
        uint256 _fee,
        address hcAddr,
        address hnAddr,
        address receivingAddr,
        address manager
    ) VRFConsumerBase(vrfAddr, linkAddr) {
        keyHash = _keyHash;
        fee = _fee;

        hc = IERC20(hcAddr);
        hn = IHN(hnAddr);

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Key Hash
     */
    function setKeyHash(bytes32 _keyHash) external onlyRole(MANAGER_ROLE) {
        keyHash = _keyHash;
    }

    /**
     * @dev Set Fee
     */
    function setFee(uint256 _fee) external onlyRole(MANAGER_ROLE) {
        fee = _fee;
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
        bool _vrfFlag,
        uint256 _ultraRate,
        uint256 _crossRate,
        uint256 _hcBase,
        uint256 _hcRange,
        uint256 _hashratesBase,
        uint256 _hashratesRange
    ) external onlyRole(MANAGER_ROLE) {
        vrfFlag = _vrfFlag;
        ultraRate = _ultraRate;
        crossRate = _crossRate;
        hcBase = _hcBase;
        hcRange = _hcRange;
        hashratesBase = _hashratesBase;
        hashratesRange = _hashratesRange;

        emit SetDatas(
            _vrfFlag,
            _ultraRate,
            _crossRate,
            _hcBase,
            _hcRange,
            _hashratesBase,
            _hashratesRange
        );
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
        uint256 series = hn.series(hnIds[0]);

        uint256 upgradePrice = getUpgradePrice(hnIds);
        hc.safeTransferFrom(msg.sender, receivingAddress, upgradePrice);

        uint256[] memory upgradedHnIds = new uint256[](hnIds.length / 4);
        uint256[][] memory upgradedHashrates = new uint256[][](
            hnIds.length / 4
        );
        uint256[] memory sameClassCounts = new uint256[](hnIds.length / 4);
        for (uint256 index = 0; index < hnIds.length; index += 4) {
            uint256 hnId = hnIds[index];
            upgradedHnIds[index / 4] = hnId;

            uint256[] memory materialHnIds = new uint256[](3);
            materialHnIds[0] = hnIds[index + 1];
            materialHnIds[1] = hnIds[index + 2];
            materialHnIds[2] = hnIds[index + 3];

            require(hn.ownerOf(hnId) == msg.sender, "This Hn is not own");
            require(hn.level(hnId) == level, "Hn level mismatch");
            require(hn.series(hnId) == series, "Hn series mismatch");

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
                require(
                    hn.series(materialHnIds[i]) == series,
                    "Material series mismatch"
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
                upgradedHashrates[index / 4] = hashrates;

                uint256 materialClass = hn.data(materialHnIds[i], "class");
                materialClass = materialClass > 0
                    ? materialClass
                    : hn.getRandomNumber(materialHnIds[i], "class", 1, 4);
                if (class == materialClass) sameClassCount++;
                sameClassCounts[index / 4] = sameClassCount;
            }

            if (vrfFlag) {
                require(
                    LINK.balanceOf(address(this)) >= fee,
                    "Not Enough LINK"
                );
                bytes32 requestId = requestRandomness(keyHash, fee);
                requestIdToUser[requestId] = msg.sender;
                requestIdToLevel[requestId] = level;
                requestIdToUpgradedHnIds[requestId] = upgradedHnIds;
                requestIdToUpgradedHashrates[requestId] = upgradedHashrates;
                requestIdToSameClassCounts[requestId] = sameClassCounts;
            } else {
                upgradeHns(
                    msg.sender,
                    level,
                    upgradedHnIds,
                    upgradedHashrates,
                    sameClassCounts
                );
            }

            userUpgradeCount[msg.sender]++;
            totalUpgradeCount++;
        }

        userUpgradeAmount[msg.sender] += upgradePrice;
        totalUpgradeAmount += upgradePrice;
        users.add(msg.sender);

        emit Upgrade(msg.sender, level, hnIds.length);
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

    /**
     * @dev Upgrade Hns to User when get Randomness Response
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256[] memory levels = new uint256[](
            requestIdToUpgradedHnIds[requestId].length
        );
        bool[] memory ultras = new bool[](
            requestIdToUpgradedHnIds[requestId].length
        );
        for (
            uint256 index = 0;
            index < requestIdToUpgradedHnIds[requestId].length;
            index++
        ) {
            hn.setLevel(
                requestIdToUpgradedHnIds[requestId][index],
                requestIdToLevel[requestId] + 1
            );

            uint256 random;
            for (
                uint256 i = 0;
                i < requestIdToUpgradedHashrates[requestId][index].length;
                i++
            ) {
                random = uint256(
                    keccak256(
                        abi.encodePacked(
                            requestIdToUser[requestId],
                            block.number,
                            totalUpgradeCount,
                            userUpgradeCount[requestIdToUser[requestId]],
                            requestIdToUpgradedHnIds[requestId][index],
                            users.length(),
                            requestIdToUpgradedHashrates[requestId][index][i],
                            requestIdToLevel[requestId],
                            i
                        )
                    )
                );

                if (
                    i == 0 &&
                    requestIdToUpgradedHashrates[requestId][index][i] == 0
                ) {
                    requestIdToUpgradedHashrates[requestId][index][i] =
                        hcBase +
                        ((random % 1e10) % hcRange);
                } else {
                    requestIdToUpgradedHashrates[requestId][index][i] =
                        (requestIdToUpgradedHashrates[requestId][index][i] *
                            (hcBase +
                                ((
                                    i == 0
                                        ? requestIdToLevel[requestId] - 1
                                        : requestIdToLevel[requestId]
                                ) * hashratesBase) +
                                (requestIdToSameClassCounts[requestId][index] *
                                    hashratesRange) +
                                ((random % 1e10) % hashratesRange))) /
                        hcBase;
                }
            }
            hn.setHashrates(
                requestIdToUpgradedHnIds[requestId][index],
                requestIdToUpgradedHashrates[requestId][index]
            );

            if (
                hn.series(requestIdToUpgradedHnIds[requestId][index]) >= 2 &&
                (randomness % 1e4) < ultraRate
            ) {
                hn.setData(
                    requestIdToUpgradedHnIds[requestId][index],
                    "ultra",
                    1
                );
            }

            if (
                requestIdToLevel[requestId] <= 3 &&
                ((randomness % 1e8) / 1e4) < crossRate
            ) {
                requestIdToLevel[requestId]++;
                hn.setLevel(
                    requestIdToUpgradedHnIds[requestId][index],
                    requestIdToLevel[requestId] + 1
                );

                for (
                    uint256 i = 0;
                    i < requestIdToUpgradedHashrates[requestId][index].length;
                    i++
                ) {
                    random = uint256(
                        keccak256(
                            abi.encodePacked(
                                requestIdToUser[requestId],
                                block.number,
                                totalUpgradeCount,
                                userUpgradeCount[requestIdToUser[requestId]],
                                requestIdToUpgradedHnIds[requestId][index],
                                users.length(),
                                requestIdToUpgradedHashrates[requestId][index][
                                    i
                                ],
                                requestIdToLevel[requestId],
                                i
                            )
                        )
                    );

                    requestIdToUpgradedHashrates[requestId][index][i] =
                        (requestIdToUpgradedHashrates[requestId][index][i] *
                            4 *
                            (hcBase +
                                ((
                                    i == 0
                                        ? requestIdToLevel[requestId] - 1
                                        : requestIdToLevel[requestId]
                                ) * hashratesBase) +
                                (requestIdToSameClassCounts[requestId][index] *
                                    hashratesRange) +
                                ((random % 1e10) % hashratesRange))) /
                        hcBase;
                }
                hn.setHashrates(
                    requestIdToUpgradedHnIds[requestId][index],
                    requestIdToUpgradedHashrates[requestId][index]
                );
            }

            levels[index] = requestIdToLevel[requestId] + 1;
            ultras[index] = hn.data(
                requestIdToUpgradedHnIds[requestId][index],
                "ultra"
            ) == 1
                ? true
                : false;
            randomness /= 1e8;
        }

        emit UpgradeHns(
            requestIdToUser[requestId],
            levels,
            requestIdToUpgradedHnIds[requestId].length,
            requestIdToUpgradedHnIds[requestId],
            ultras
        );
    }

    /**
     * @dev Upgrade Hns
     */
    function upgradeHns(
        address user,
        uint256 level,
        uint256[] memory upgradedHnIds,
        uint256[][] memory upgradedHashrates,
        uint256[] memory sameClassCounts
    ) private {
        uint256[] memory levels = new uint256[](upgradedHnIds.length);
        bool[] memory ultras = new bool[](upgradedHnIds.length);
        for (uint256 index = 0; index < upgradedHnIds.length; index++) {
            hn.setLevel(upgradedHnIds[index], level + 1);

            uint256 randomness;
            for (uint256 i = 0; i < upgradedHashrates[index].length; i++) {
                randomness = uint256(
                    keccak256(
                        abi.encodePacked(
                            user,
                            block.number,
                            totalUpgradeCount,
                            userUpgradeCount[user],
                            upgradedHnIds[index],
                            users.length(),
                            upgradedHashrates[index][i],
                            level,
                            i
                        )
                    )
                );

                if (i == 0 && upgradedHashrates[index][i] == 0) {
                    upgradedHashrates[index][i] =
                        hcBase +
                        ((randomness % 1e10) % hcRange);
                } else {
                    upgradedHashrates[index][i] =
                        (upgradedHashrates[index][i] *
                            (hcBase +
                                ((i == 0 ? level - 1 : level) * hashratesBase) +
                                (sameClassCounts[index] * hashratesRange) +
                                ((randomness % 1e10) % hashratesRange))) /
                        hcBase;
                }
            }
            hn.setHashrates(upgradedHnIds[index], upgradedHashrates[index]);

            if (
                hn.series(upgradedHnIds[index]) >= 2 &&
                ((randomness % 1e14) / 1e10) < ultraRate
            ) {
                hn.setData(upgradedHnIds[index], "ultra", 1);
            }

            if (level <= 3 && ((randomness % 1e18) / 1e14) < crossRate) {
                level++;
                hn.setLevel(upgradedHnIds[index], level + 1);

                for (uint256 i = 0; i < upgradedHashrates[index].length; i++) {
                    randomness = uint256(
                        keccak256(
                            abi.encodePacked(
                                user,
                                block.number,
                                totalUpgradeCount,
                                userUpgradeCount[user],
                                upgradedHnIds[index],
                                users.length(),
                                upgradedHashrates[index][i],
                                level,
                                i
                            )
                        )
                    );

                    upgradedHashrates[index][i] =
                        (upgradedHashrates[index][i] *
                            4 *
                            (hcBase +
                                ((i == 0 ? level - 1 : level) * hashratesBase) +
                                (sameClassCounts[index] * hashratesRange) +
                                ((randomness % 1e10) % hashratesRange))) /
                        hcBase;
                }
                hn.setHashrates(upgradedHnIds[index], upgradedHashrates[index]);
            }

            levels[index] = level + 1;
            ultras[index] = hn.data(upgradedHnIds[index], "ultra") == 1
                ? true
                : false;
        }

        emit UpgradeHns(
            user,
            levels,
            upgradedHnIds.length,
            upgradedHnIds,
            ultras
        );
    }
}
