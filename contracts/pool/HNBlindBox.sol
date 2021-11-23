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

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(uint256 => uint256) public boxTokenPrices;
    mapping(uint256 => address) public tokenAddrs;
    mapping(uint256 => address) public receivingAddrs;

    mapping(uint256 => uint256) public boxesMaxSupply;
    mapping(uint256 => uint256) public totalBoxesLength;

    uint256 public btcBase = 10000;
    uint256 public btcRange = 1000;

    mapping(uint256 => uint256) public totalTokenBuyAmount;
    mapping(address => uint256) public userBoxesLength;
    mapping(address => mapping(uint256 => uint256)) public userTokenBuyAmount;

    EnumerableSet.AddressSet private users;

    event SetTokenInfo(
        uint256 tokenId,
        uint256 boxTokenPrice,
        address tokenAddr,
        address receivingAddr
    );
    event AddBoxesMaxSupply(uint256 supply, uint256 tokenId);
    event SetDatas(uint256 btcBase, uint256 btcRange);
    event BuyBoxes(address indexed user, uint256 tokenId, uint256 price);
    event SpawnHns(address indexed user, uint256 boxesLength, uint256[] hnIds);

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
        address receivingAddr
    ) external onlyRole(MANAGER_ROLE) {
        boxTokenPrices[tokenId] = boxTokenPrice;
        tokenAddrs[tokenId] = tokenAddr;
        receivingAddrs[tokenId] = receivingAddr;

        emit SetTokenInfo(tokenId, boxTokenPrice, tokenAddr, receivingAddr);
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
     * @dev Set Datas
     */
    function setDatas(uint256 _btcBase, uint256 _btcRange)
        external
        onlyRole(MANAGER_ROLE)
    {
        btcBase = _btcBase;
        btcRange = _btcRange;

        emit SetDatas(_btcBase, _btcRange);
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
        require(boxesLength <= 256, "Boxes length must <= 256");
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
            address
        )
    {
        return (
            boxTokenPrices[tokenId],
            tokenAddrs[tokenId],
            receivingAddrs[tokenId]
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
     * @dev Get Boxes Left Supply
     */
    function getBoxesLeftSupply(uint256 tokenId) public view returns (uint256) {
        return boxesMaxSupply[tokenId] - totalBoxesLength[tokenId];
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

            uint256[] memory hashrates = new uint256[](2);
            hashrates[0] = 0;
            hashrates[1] = btcBase + (randomness % btcRange);

            uint256 hnId = hn.spawnHn(to, 1, 1, 1, hashrates);

            hnIds[i] = hnId;
        }

        emit SpawnHns(to, boxesLength, hnIds);
    }
}
