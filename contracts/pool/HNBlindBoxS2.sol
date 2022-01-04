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
 * @title HN-S2 Blind Box Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can draw high level HN-S2
 */
contract HNBlindBoxS2 is
    AccessControlEnumerable,
    VRFConsumerBase,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(uint256 => uint256) public boxTokenPrices;
    mapping(uint256 => address) public tokenAddrs;
    mapping(uint256 => address) public receivingAddrs;
    mapping(uint256 => uint256) public hourlyBuyLimits;
    mapping(uint256 => bool) public whiteListFlags;
    mapping(uint256 => bool) public vrfFlags;
    mapping(uint256 => uint256[]) public levelProbabilities;

    mapping(uint256 => uint256) public boxesMaxSupply;
    mapping(uint256 => uint256) public totalBoxesLength;

    uint256 public goldRate = 100;
    uint256[] public hashrateBases = [10000, 44000, 211200, 1098240, 6150144];
    uint256[] public hashrateRanges = [1000, 8800, 63360, 439296, 3075072];

    mapping(uint256 => uint256) public totalTokenBuyAmount;
    mapping(address => uint256) public userBoxesLength;
    mapping(address => mapping(uint256 => uint256)) public userTokenBuyAmount;
    mapping(address => mapping(uint256 => uint256))
        public userHourlyBoxesLength;

    EnumerableSet.AddressSet private users;
    mapping(uint256 => EnumerableSet.UintSet) private levelHnIds;
    mapping(uint256 => EnumerableSet.AddressSet) private whiteList;

    mapping(bytes32 => address) public requestIdToUser;
    mapping(bytes32 => uint256) public requestIdToBoxesLength;
    mapping(bytes32 => uint256) public requestIdToTokenId;

    bytes32 public keyHash;
    uint256 public fee;

    event SetDatas(
        uint256 goldRate,
        uint256[] hashrateBases,
        uint256[] hashrateRanges
    );
    event SetTokenInfo(
        uint256 tokenId,
        uint256 boxTokenPrice,
        address tokenAddr,
        address receivingAddr,
        uint256 hourlyBuylimit,
        bool whiteListFlag,
        bool vrfFlag,
        uint256[] levelProbability
    );
    event AddBoxesMaxSupply(uint256 supply, uint256 tokenId);
    event AddWhiteList(uint256 tokenId, address[] whiteUsers);
    event RemoveWhiteList(uint256 tokenId, address[] whiteUsers);
    event BuyBoxes(address indexed user, uint256 tokenId, uint256 price);
    event SpawnHns(
        address indexed user,
        uint256 boxesLength,
        uint256[] hnIds,
        uint256[] levels
    );

    /**
     * @param vrfAddr Initialize VRF Coordinator Address
     * @param linkAddr Initialize LINK Token Address
     * @param _keyHash Initialize Key Hash
     * @param _fee Initialize Fee
     * @param hnAddr Initialize HN Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address vrfAddr,
        address linkAddr,
        bytes32 _keyHash,
        uint256 _fee,
        address hnAddr,
        address manager
    ) VRFConsumerBase(vrfAddr, linkAddr) {
        keyHash = _keyHash;
        fee = _fee;

        hn = IHN(hnAddr);

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
     * @dev Set Datas
     */
    function setDatas(
        uint256 _goldRate,
        uint256[] calldata _hashrateBases,
        uint256[] calldata _hashrateRanges
    ) external onlyRole(MANAGER_ROLE) {
        goldRate = _goldRate;
        hashrateBases = _hashrateBases;
        hashrateRanges = _hashrateRanges;

        emit SetDatas(_goldRate, _hashrateBases, _hashrateRanges);
    }

    /**
     * @dev Set Token Info
     */
    function setTokenInfo(
        uint256 tokenId,
        uint256 boxTokenPrice,
        address tokenAddr,
        address receivingAddr,
        uint256 hourlyBuyLimit,
        bool whiteListFlag,
        bool vrfFlag,
        uint256[] calldata levelProbability
    ) external onlyRole(MANAGER_ROLE) {
        boxTokenPrices[tokenId] = boxTokenPrice;
        tokenAddrs[tokenId] = tokenAddr;
        receivingAddrs[tokenId] = receivingAddr;
        hourlyBuyLimits[tokenId] = hourlyBuyLimit;
        whiteListFlags[tokenId] = whiteListFlag;
        vrfFlags[tokenId] = vrfFlag;
        levelProbabilities[tokenId] = levelProbability;

        emit SetTokenInfo(
            tokenId,
            boxTokenPrice,
            tokenAddr,
            receivingAddr,
            hourlyBuyLimit,
            whiteListFlag,
            vrfFlag,
            levelProbability
        );
    }

    /**
     * @dev Add Boxes Max Supply
     */
    function addBoxesMaxSupply(uint256 supply, uint256 tokenId)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (vrfFlags[tokenId]) {
            LINK.transferFrom(msg.sender, address(this), supply * fee);
        }
        boxesMaxSupply[tokenId] += supply;

        emit AddBoxesMaxSupply(supply, tokenId);
    }

    /**
     * @dev Add White List
     */
    function addWhiteList(uint256 tokenId, address[] calldata whiteUsers)
        external
        onlyRole(MANAGER_ROLE)
    {
        for (uint256 i = 0; i < whiteUsers.length; i++) {
            whiteList[tokenId].add(whiteUsers[i]);
        }

        emit AddWhiteList(tokenId, whiteUsers);
    }

    /**
     * @dev Remove White List
     */
    function removeWhiteList(uint256 tokenId, address[] calldata whiteUsers)
        external
        onlyRole(MANAGER_ROLE)
    {
        for (uint256 i = 0; i < whiteUsers.length; i++) {
            whiteList[tokenId].remove(whiteUsers[i]);
        }

        emit RemoveWhiteList(tokenId, whiteUsers);
    }

    /**
     * @dev Buy Boxes
     */
    function buyBoxes(uint256 boxesLength, uint256 tokenId)
        external
        payable
        nonReentrant
    {
        require(boxesLength > 0, "Boxes length must > 0");
        require(
            getUserHourlyBoxesLeftSupply(
                tokenId,
                msg.sender,
                block.timestamp
            ) >= boxesLength,
            "Boxes length exceeds the hourly buy limit"
        );
        require(
            getBoxesLeftSupply(tokenId) >= boxesLength,
            "Not enough boxes supply"
        );
        require(
            boxTokenPrices[tokenId] > 0,
            "The box price of this token has not been set"
        );
        require(
            tokenAddrs[tokenId] != address(0),
            "The token address of this token has not been set"
        );
        require(
            receivingAddrs[tokenId] != address(0),
            "The receiving address of this token has not been set"
        );
        require(
            levelProbabilities[tokenId].length == 5,
            "The level probability of this token has not been set"
        );
        if (whiteListFlags[tokenId]) {
            require(
                whiteList[tokenId].contains(msg.sender),
                "Your address must be on the whitelist"
            );
        }

        uint256 price = boxesLength * boxTokenPrices[tokenId];
        if (tokenId == 0) {
            require(msg.value == price, "Price mismatch");
            payable(receivingAddrs[tokenId]).transfer(price);
        } else {
            IERC20 token = IERC20(tokenAddrs[tokenId]);
            token.safeTransferFrom(msg.sender, receivingAddrs[tokenId], price);
        }

        if (vrfFlags[tokenId]) {
            require(LINK.balanceOf(address(this)) >= fee, "Not Enough LINK");
            bytes32 requestId = requestRandomness(keyHash, fee);
            requestIdToUser[requestId] = msg.sender;
            requestIdToBoxesLength[requestId] = boxesLength;
            requestIdToTokenId[requestId] = tokenId;
        } else {
            spawnHns(msg.sender, boxesLength, tokenId);
        }

        userBoxesLength[msg.sender] += boxesLength;
        userHourlyBoxesLength[msg.sender][
            block.timestamp / 3600
        ] += boxesLength;
        userTokenBuyAmount[msg.sender][tokenId] += price;
        totalBoxesLength[tokenId] += boxesLength;
        totalTokenBuyAmount[tokenId] += price;
        users.add(msg.sender);

        emit BuyBoxes(msg.sender, tokenId, price);
    }

    /**
     * @dev Get Token Info
     */
    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (
            uint256,
            address,
            address,
            uint256,
            bool,
            bool,
            uint256[] memory
        )
    {
        return (
            boxTokenPrices[tokenId],
            tokenAddrs[tokenId],
            receivingAddrs[tokenId],
            hourlyBuyLimits[tokenId],
            whiteListFlags[tokenId],
            vrfFlags[tokenId],
            levelProbabilities[tokenId]
        );
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
     * @dev Get Each Level HnIds Length
     */
    function getEachLevelHnIdsLength(uint256 maxLevel)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory lengths = new uint256[](maxLevel);
        for (uint256 i = 0; i < maxLevel; i++) {
            lengths[i] = levelHnIds[i + 1].length();
        }
        return lengths;
    }

    /**
     * @dev Get Level HnIds Length
     */
    function getLevelHnIdsLength(uint256 level)
        external
        view
        returns (uint256)
    {
        return levelHnIds[level].length();
    }

    /**
     * @dev Get Level HnIds by Size
     */
    function getLevelHnIdsBySize(
        uint256 level,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > levelHnIds[level].length() - cursor) {
            length = levelHnIds[level].length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = levelHnIds[level].at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get White List Existence
     */
    function getWhiteListExistence(uint256 tokenId, address user)
        external
        view
        returns (bool)
    {
        return whiteList[tokenId].contains(user);
    }

    /**
     * @dev Get White List Length
     */
    function getWhiteListLength(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return whiteList[tokenId].length();
    }

    /**
     * @dev Get White List by Size
     */
    function getWhiteListBySize(
        uint256 tokenId,
        uint256 cursor,
        uint256 size
    ) external view returns (address[] memory, uint256) {
        uint256 length = size;
        if (length > whiteList[tokenId].length() - cursor) {
            length = whiteList[tokenId].length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = whiteList[tokenId].at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Boxes Left Supply
     */
    function getBoxesLeftSupply(uint256 tokenId) public view returns (uint256) {
        return boxesMaxSupply[tokenId] - totalBoxesLength[tokenId];
    }

    /**
     * @dev Get User Hourly Boxes Left Supply
     */
    function getUserHourlyBoxesLeftSupply(
        uint256 tokenId,
        address user,
        uint256 timestamp
    ) public view returns (uint256) {
        return
            hourlyBuyLimits[tokenId] -
            userHourlyBoxesLength[user][timestamp / 3600];
    }

    /**
     * @dev Get Level
     */
    function getLevel(uint256 tokenId, uint256 random)
        public
        view
        returns (uint256)
    {
        uint256 accProbability;
        uint256 level;
        for (uint256 i = 0; i < levelProbabilities[tokenId].length; i++) {
            accProbability += levelProbabilities[tokenId][i];
            if (random < accProbability) {
                level = i;
                break;
            }
        }
        return level + 1;
    }

    /**
     * @dev Spawn HN to User when get Randomness Response
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256[] memory hnIds = new uint256[](
            requestIdToBoxesLength[requestId]
        );
        uint256[] memory levels = new uint256[](
            requestIdToBoxesLength[requestId]
        );
        for (uint256 i = 0; i < requestIdToBoxesLength[requestId]; i++) {
            uint256 level = getLevel(
                requestIdToTokenId[requestId],
                randomness % 1e4
            );
            uint256 hcBase = level >= 2 ? hashrateBases[level - 2] : 0;
            uint256 hcRange = level >= 2 ? hashrateRanges[level - 2] : 1;

            uint256[] memory hashrates = new uint256[](2);
            hashrates[0] = hcBase + (((randomness % 1e14) / 1e4) % hcRange);

            uint256 hnId = hn.spawnHn(
                requestIdToUser[requestId],
                1,
                2,
                level,
                hashrates
            );

            if (((randomness % 1e18) / 1e14) < goldRate) {
                hn.setData(hnId, "gold", 1);
            }

            hnIds[i] = hnId;
            levels[i] = level;
            levelHnIds[level].add(hnId);
            randomness /= 1e18;
        }

        emit SpawnHns(
            requestIdToUser[requestId],
            requestIdToBoxesLength[requestId],
            hnIds,
            levels
        );
    }

    /**
     * @dev Spawn Hns
     */
    function spawnHns(
        address to,
        uint256 boxesLength,
        uint256 tokenId
    ) private {
        uint256[] memory hnIds = new uint256[](boxesLength);
        uint256[] memory levels = new uint256[](boxesLength);
        for (uint256 i = 0; i < boxesLength; i++) {
            uint256 randomness = uint256(
                keccak256(
                    abi.encodePacked(
                        to,
                        block.number,
                        boxesLength,
                        boxTokenPrices[tokenId],
                        boxesMaxSupply[tokenId],
                        totalBoxesLength[tokenId],
                        userBoxesLength[to],
                        users.length(),
                        i
                    )
                )
            );

            uint256 level = getLevel(tokenId, randomness % 1e4);
            uint256 hcBase = level >= 2 ? hashrateBases[level - 2] : 0;
            uint256 hcRange = level >= 2 ? hashrateRanges[level - 2] : 1;

            uint256[] memory hashrates = new uint256[](2);
            hashrates[0] = hcBase + (((randomness % 1e14) / 1e4) % hcRange);

            uint256 hnId = hn.spawnHn(to, 1, 2, level, hashrates);

            if (((randomness % 1e18) / 1e14) < goldRate) {
                hn.setData(hnId, "gold", 1);
            }

            hnIds[i] = hnId;
            levels[i] = level;
            levelHnIds[level].add(hnId);
        }

        emit SpawnHns(to, boxesLength, hnIds, levels);
    }
}
