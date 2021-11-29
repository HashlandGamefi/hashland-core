// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Blind Box Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can draw high level HN
 */
contract HNBlindBox is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(uint256 => uint256) public boxTokenPrices;
    mapping(uint256 => address) public tokenAddrs;
    mapping(uint256 => address) public receivingAddrs;
    mapping(uint256 => uint256) public maxBuyLengths;
    mapping(uint256 => bool) public whiteListFlags;
    mapping(uint256 => uint256[]) public levelProbabilities;

    mapping(uint256 => uint256) public boxesMaxSupply;
    mapping(uint256 => uint256) public totalBoxesLength;

    uint256[] public hashrateBases = [10000, 44000, 211200, 1098240, 6150144];
    uint256[] public hashrateRanges = [1000, 8800, 63360, 439296, 3075072];

    mapping(uint256 => uint256) public totalTokenBuyAmount;
    mapping(address => uint256) public userBoxesLength;
    mapping(address => mapping(uint256 => uint256)) public userTokenBuyAmount;

    EnumerableSet.AddressSet private users;
    mapping(uint256 => EnumerableSet.UintSet) private levelHnIds;
    mapping(uint256 => EnumerableSet.AddressSet) private whiteList;

    event SetTokenInfo(
        uint256 tokenId,
        uint256 boxTokenPrice,
        address tokenAddr,
        address receivingAddr,
        uint256 maxBuyAmount,
        bool whiteListFlag,
        uint256[] levelProbability
    );
    event AddBoxesMaxSupply(uint256 supply, uint256 tokenId);
    event BuyBoxes(address indexed user, uint256 tokenId, uint256 price);
    event SpawnHns(
        address indexed user,
        uint256 boxesLength,
        uint256[] hnIds,
        uint256[] levels
    );

    /**
     * @param hnAddr Initialize HN Address
     * @param manager Initialize Manager Role
     */
    constructor(address hnAddr, address manager) {
        hn = IHN(hnAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Token Info
     */
    function setTokenInfo(
        uint256 tokenId,
        uint256 boxTokenPrice,
        address tokenAddr,
        address receivingAddr,
        uint256 maxBuyLength,
        bool whiteListFlag,
        uint256[] calldata levelProbability
    ) external onlyRole(MANAGER_ROLE) {
        boxTokenPrices[tokenId] = boxTokenPrice;
        tokenAddrs[tokenId] = tokenAddr;
        receivingAddrs[tokenId] = receivingAddr;
        maxBuyLengths[tokenId] = maxBuyLength;
        whiteListFlags[tokenId] = whiteListFlag;
        levelProbabilities[tokenId] = levelProbability;

        emit SetTokenInfo(
            tokenId,
            boxTokenPrice,
            tokenAddr,
            receivingAddr,
            maxBuyLength,
            whiteListFlag,
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
            boxesLength <= maxBuyLengths[tokenId],
            "Boxes length exceeds the limit"
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

        spawnHns(msg.sender, boxesLength, tokenId);

        userBoxesLength[msg.sender] += boxesLength;
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
            uint256[] memory
        )
    {
        return (
            boxTokenPrices[tokenId],
            tokenAddrs[tokenId],
            receivingAddrs[tokenId],
            maxBuyLengths[tokenId],
            whiteListFlags[tokenId],
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
            uint256 btcBase = hashrateBases[level - 1];
            uint256 btcRange = hashrateRanges[level - 1];
            uint256 hcBase = level >= 2 ? hashrateBases[level - 2] : 0;
            uint256 hcRange = level >= 2 ? hashrateRanges[level - 2] : 1;

            uint256[] memory hashrates = new uint256[](2);
            hashrates[0] = hcBase + (((randomness % 1e14) / 1e4) % hcRange);
            hashrates[1] = btcBase + (((randomness % 1e24) / 1e14) % btcRange);

            uint256 hnId = hn.spawnHn(to, 1, 1, level, hashrates);

            hnIds[i] = hnId;
            levels[i] = level;
            levelHnIds[level].add(hnId);
        }

        emit SpawnHns(to, boxesLength, hnIds, levels);
    }
}
