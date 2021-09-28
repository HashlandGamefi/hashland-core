// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Box Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Draw HN
 */
contract HNBox is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public receivingAddress;

    uint256 public boxBNBPrice = 0.25 * 1e18;
    uint256 public boxesMaxSupply;
    uint256 public totalBoxesLength;
    uint256 public totalBNBBuyAmount;

    bool public isRaceEqualsClass = true;
    uint256 public raceLength = 3;
    uint256 public classLength = 3;
    uint256 public itemsLength = 20;
    uint256 public attrsLength = 5;

    mapping(address => uint256) public userBoxesLength;
    mapping(address => uint256) public userBNBBuyAmount;

    EnumerableSet.AddressSet private users;

    event BuyBoxes(address indexed user, uint256 boxesLength, uint256[] hnIds);

    /**
     * @param hnAddr Initialize HN Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address receivingAddr,
        address manager
    ) {
        hn = IHN(hnAddr);

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Box BNB Price
     */
    function setBoxBNBPrice(uint256 _boxBNBPrice)
        external
        onlyRole(MANAGER_ROLE)
    {
        boxBNBPrice = _boxBNBPrice;
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
     * @dev Add Boxes Max Supply
     */
    function addBoxesMaxSupply(uint256 supply) external onlyRole(MANAGER_ROLE) {
        boxesMaxSupply += supply;
    }

    /**
     * @dev Set Datas
     */
    function setDatas(
        bool _isRaceEqualsClass,
        uint256 _raceLength,
        uint256 _classLength,
        uint256 _itemsLength,
        uint256 _attrsLength
    ) external onlyRole(MANAGER_ROLE) {
        isRaceEqualsClass = _isRaceEqualsClass;
        raceLength = _raceLength;
        classLength = _classLength;
        itemsLength = _itemsLength;
        attrsLength = _attrsLength;
    }

    /**
     * @dev Buy Boxes By BNB
     */
    receive() external payable {
        uint256 boxesLength = msg.value / boxBNBPrice;
        require(boxesLength > 0, "Boxes Length must > 0");
        require(boxesLength <= 10, "The Boxes Length must <= 10");
        require(getBoxesLeftSupply() >= boxesLength, "Not Enough Boxes Supply");

        uint256 buyAmount = boxesLength * boxBNBPrice;
        payable(receivingAddress).transfer(buyAmount);

        uint256[] memory hashrates = new uint256[](2);
        hashrates[0] = 100;
        hashrates[1] = 100;
        uint256[] memory hnIds = new uint256[](boxesLength);
        for (uint256 i = 0; i < boxesLength; i++) {
            uint256 randomness = uint256(
                keccak256(
                    abi.encodePacked(
                        boxBNBPrice,
                        boxesMaxSupply,
                        totalBoxesLength,
                        totalBNBBuyAmount,
                        userBoxesLength[msg.sender],
                        userBNBBuyAmount[msg.sender],
                        users.length(),
                        msg.sender,
                        msg.value,
                        block.timestamp,
                        i
                    )
                )
            );
            uint256 race = ((randomness % 1e2) % raceLength) + 1;
            uint256 class = (((randomness % 1e4) / 1e2) % classLength) + 1;
            uint256[] memory items = new uint256[](2);
            items[0] = (((randomness % 1e6) / 1e4) % itemsLength) + 1;
            items[1] = (((randomness % 1e8) / 1e4) % itemsLength) + 1;
            uint256[] memory attrs = new uint256[](6);
            attrs[0] = (((randomness % 1e10) / 1e8) % attrsLength) + 10;
            attrs[1] = (((randomness % 1e12) / 1e10) % attrsLength) + 10;
            attrs[2] = (((randomness % 1e14) / 1e12) % attrsLength) + 10;
            attrs[3] = (((randomness % 1e16) / 1e14) % attrsLength) + 10;
            attrs[4] = (((randomness % 1e18) / 1e16) % attrsLength) + 10;
            attrs[5] = (((randomness % 1e20) / 1e18) % attrsLength) + 10;

            uint256 hnId = hn.spawnHn(msg.sender, 1, 1, hashrates);
            hn.setData(hnId, "race", race);
            hn.setData(hnId, "class", isRaceEqualsClass ? race : class);
            hn.setDatas(hnId, "items", items);
            hn.setDatas(hnId, "attrs", attrs);

            hnIds[i] = hnId;
        }

        userBoxesLength[msg.sender] += boxesLength;
        userBNBBuyAmount[msg.sender] += buyAmount;
        totalBoxesLength += boxesLength;
        totalBNBBuyAmount += buyAmount;
        users.add(msg.sender);

        uint256 returnAmount = msg.value - buyAmount;
        if (returnAmount > 0) payable(msg.sender).transfer(returnAmount);

        emit BuyBoxes(msg.sender, boxesLength, hnIds);
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
     * @dev Get Boxes Left Supply
     */
    function getBoxesLeftSupply() public view returns (uint256) {
        return boxesMaxSupply - totalBoxesLength;
    }
}
