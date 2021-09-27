// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../token/interface/IHN.sol";

/**
 * @title HN Box Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Draw HN
 */
contract HNBox is AccessControlEnumerable {
    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public receivingAddress;

    uint256 public boxBNBPrice = 0.25 * 1e18;
    uint256 public boxesMaxSupply;
    uint256 public totalBoxesLength;
    uint256 public totalBNBBuyAmount;

    mapping(address => uint256) public userBoxesLength;
    mapping(address => uint256) public userBNBBuyAmount;

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
     * @dev Withdraw BNB
     */
    function withdrawBNB(address to, uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
    {
        payable(to).transfer(amount);
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
     * @dev Buy Boxes By BNB
     */
    receive() external payable {
        uint256 boxesLength = msg.value / boxBNBPrice;
        require(boxesLength > 0, "Boxes Length must > 0");
        require(boxesLength <= 10, "The Boxes Length must <= 10");
        require(getBoxesLeftSupply() >= boxesLength, "Not Enough Boxes Supply");

        uint256 buyAmount = boxesLength * boxBNBPrice;
        payable(receivingAddress).transfer(buyAmount);

        uint256[] memory hashrates = new uint256[](1);
        hashrates[0] = 100;
        uint256[] memory hnIds = new uint256[](boxesLength);
        uint256 randomness;
        for (uint256 i = 0; i < boxesLength; i++) {
            uint256 hnId = hn.spawnHn(msg.sender, 1, 1, hashrates);

            hnIds[i] = hnId;
            randomness /= 1e6;
        }

        userBoxesLength[msg.sender] += boxesLength;
        userBNBBuyAmount[msg.sender] += buyAmount;
        totalBoxesLength += boxesLength;
        totalBNBBuyAmount += buyAmount;

        uint256 returnAmount = msg.value - buyAmount;
        if (returnAmount > 0) payable(msg.sender).transfer(returnAmount);

        emit BuyBoxes(msg.sender, boxesLength, hnIds);
    }

    /**
     * @dev Get Boxes Left Supply
     */
    function getBoxesLeftSupply() public view returns (uint256) {
        return boxesMaxSupply - totalBoxesLength;
    }
}
