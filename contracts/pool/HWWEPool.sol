// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHC.sol";

/**
 * @title Hash Warfare World Event Pool Contract
 * @author HASHLAND-TEAM
 * @notice In this contract, players can harvest HC of World Event rewards
 */
contract HWWEPool is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IHC;
    using EnumerableSet for EnumerableSet.AddressSet;

    IHC public hc;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public storedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public userStoredToken;
    mapping(address => uint256) public userHarvestedToken;

    EnumerableSet.AddressSet private users;

    event AddRewards(address[] users, uint256[] amounts, uint256 totalAmount);
    event RemoveRewards(
        address[] users,
        uint256[] amounts,
        uint256 totalAmount
    );
    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hcAddr Initialize HC Address
     * @param manager Initialize Manager Role
     */
    constructor(address hcAddr, address manager) {
        hc = IHC(hcAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Add Rewards
     */
    function addRewards(
        address[] calldata rewardUsers,
        uint256[] calldata amounts
    ) external onlyRole(MANAGER_ROLE) {
        require(
            rewardUsers.length == amounts.length,
            "Data length does not match"
        );

        uint256 totalAmount;
        for (uint256 i = 0; i < rewardUsers.length; i++) {
            userStoredToken[rewardUsers[i]] += amounts[i];
            totalAmount += amounts[i];
        }
        storedToken += totalAmount;

        emit AddRewards(rewardUsers, amounts, totalAmount);
    }

    /**
     * @dev Remove Rewards
     */
    function removeRewards(
        address[] calldata rewardUsers,
        uint256[] calldata amounts
    ) external onlyRole(MANAGER_ROLE) {
        require(
            rewardUsers.length == amounts.length,
            "Data length does not match"
        );

        uint256 totalAmount;
        for (uint256 i = 0; i < rewardUsers.length; i++) {
            userStoredToken[rewardUsers[i]] -= amounts[i];
            totalAmount += amounts[i];
        }
        storedToken -= totalAmount;

        emit RemoveRewards(rewardUsers, amounts, totalAmount);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken() external nonReentrant {
        uint256 amount = userStoredToken[msg.sender];
        require(amount > 0, "Not enough token to harvest");

        userStoredToken[msg.sender] = 0;
        userHarvestedToken[msg.sender] += amount;
        harvestedToken += amount;

        hc.safeTransfer(msg.sender, amount);

        users.add(msg.sender);

        emit HarvestToken(msg.sender, amount);
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
     * @dev Get Left Token
     */
    function getLeftToken() external view returns (uint256) {
        return getReleasedToken() - storedToken;
    }

    /**
     * @dev Get Released Token
     */
    function getReleasedToken() public view returns (uint256) {
        return harvestedToken + hc.balanceOf(address(this));
    }
}
