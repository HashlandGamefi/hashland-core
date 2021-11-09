// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title HC PE Pool Contract
 * @author HASHLAND-TEAM
 * @notice In this contract PE round users can harvest HC
 */
contract HCPEPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public hc;

    uint256 public constant blockPerDay = 28800;
    uint256 public constant blockPerYear = blockPerDay * 365;
    uint256 public constant blockPerQuarter = blockPerYear / 4;

    uint256 public constant hcStartBlock = 12507000;
    uint256 public constant releaseStartBlock = hcStartBlock + blockPerQuarter;
    uint256 public constant releaseEndBlock = releaseStartBlock + blockPerYear;
    uint256 public constant releasedTotalToken = (120e4 * 1e18 * 90) / 100;
    uint256 public constant tokenPerBlock = releasedTotalToken / blockPerYear;

    uint256 public lastRewardBlock = releaseStartBlock;

    uint256 public stake;
    uint256 public accTokenPerStake;
    uint256 public releasedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public userStake;
    mapping(address => uint256) public userLastAccTokenPerStake;
    mapping(address => uint256) public userStoredToken;
    mapping(address => uint256) public userHarvestedToken;

    EnumerableSet.AddressSet private users;

    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hcAddr Initialize HC Address
     * @param userAddrs Initialize users
     * @param userStakes Initialize user stake
     */
    constructor(
        address hcAddr,
        address[] memory userAddrs,
        uint256[] memory userStakes
    ) {
        require(
            userAddrs.length == userStakes.length,
            "Data length does not match"
        );

        hc = IERC20(hcAddr);

        for (uint256 i = 0; i < userAddrs.length; i++) {
            userStake[userAddrs[i]] += userStakes[i];
            stake += userStakes[i];
            users.add(userAddrs[i]);
        }
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken() external nonReentrant {
        updatePool();

        uint256 pendingToken = (userStake[msg.sender] *
            (accTokenPerStake - userLastAccTokenPerStake[msg.sender])) / 1e18;
        uint256 amount = userStoredToken[msg.sender] + pendingToken;
        require(amount > 0, "Not enough token to harvest");

        userStoredToken[msg.sender] = 0;
        userLastAccTokenPerStake[msg.sender] = accTokenPerStake;
        userHarvestedToken[msg.sender] += amount;
        harvestedToken += amount;

        hc.safeTransfer(msg.sender, amount);

        emit HarvestToken(msg.sender, amount);
    }

    /**
     * @dev Get Token Total Rewards of a User
     */
    function getTokenTotalRewards(address user)
        external
        view
        returns (uint256)
    {
        return userHarvestedToken[user] + getTokenRewards(user);
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
     * @dev Update Pool
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 rewardsBlock = releaseEndBlock < block.number
            ? releaseEndBlock
            : block.number;
        if (rewardsBlock > lastRewardBlock && stake > 0) {
            uint256 amount = tokenPerBlock * (rewardsBlock - lastRewardBlock);
            accTokenPerStake += (amount * 1e18) / stake;
            releasedToken += amount;
        }

        lastRewardBlock = block.number;
    }

    /**
     * @dev Get Token Rewards of a User
     */
    function getTokenRewards(address user) public view returns (uint256) {
        uint256 accTokenPerStakeTemp = accTokenPerStake;
        uint256 rewardsBlock = releaseEndBlock < block.number
            ? releaseEndBlock
            : block.number;
        if (rewardsBlock > lastRewardBlock && stake > 0) {
            accTokenPerStakeTemp +=
                (tokenPerBlock * (rewardsBlock - lastRewardBlock) * 1e18) /
                stake;
        }

        return
            userStoredToken[user] +
            ((userStake[user] *
                (accTokenPerStakeTemp - userLastAccTokenPerStake[user])) /
                1e18);
    }
}
