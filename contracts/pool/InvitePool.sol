// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";
import "../token/interface/IHC.sol";
import "../pool/interface/IHNPool.sol";

/**
 * @title Invite Pool Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Harvest HC
 */
contract InvitePool is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IHN public hn;
    IHC public hc;
    IHNPool public hnPool;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant HNPOOL_ROLE = keccak256("HNPOOL_ROLE");

    bool public openStatus = false;
    uint256 public lastRewardsTime;

    uint256 public tokenReleaseSpeed = 4166666666666666;

    uint256 public stake;
    uint256 public accTokenPerStake;
    uint256 public releasedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public userStake;
    mapping(address => uint256) public userLastAccTokenPerStake;
    mapping(address => uint256) public userStoredToken;
    mapping(address => uint256) public userHarvestedToken;
    mapping(address => address) public userInviter;

    EnumerableSet.AddressSet private users;
    EnumerableSet.AddressSet private inviters;
    mapping(address => EnumerableSet.AddressSet) private inviterUsers;

    event BindInviter(address indexed user, address indexed inviter);
    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hnAddr Initialize HN Address
     * @param hcAddr Initialize HC Address
     * @param hnPoolAddr Initialize HNPool Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address hcAddr,
        address hnPoolAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        hc = IHC(hcAddr);
        hnPool = IHNPool(hnPoolAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
        _setupRole(HNPOOL_ROLE, hnPoolAddr);
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;
    }

    /**
     * @dev Deposit Inviter
     */
    function depositInviter(address user, uint256 hashrate)
        external
        onlyRole(HNPOOL_ROLE)
    {
        updatePool();

        address inviter = userInviter[user];
        if (inviter != address(0)) {
            if (userStake[inviter] > 0) {
                uint256 pendingToken = (userStake[inviter] *
                    (accTokenPerStake - userLastAccTokenPerStake[inviter])) /
                    1e18;
                if (pendingToken > 0) {
                    userStoredToken[inviter] += pendingToken;
                }
            }

            if (hashrate > 0) {
                userStake[inviter] += hashrate;
                stake += hashrate;
            }

            userLastAccTokenPerStake[inviter] = accTokenPerStake;
        }
    }

    /**
     * @dev Withdraw Inviter
     */
    function withdrawInviter(address user, uint256 hashrate)
        external
        onlyRole(HNPOOL_ROLE)
    {
        updatePool();

        address inviter = userInviter[user];
        if (inviter != address(0)) {
            if (userStake[inviter] > 0) {
                uint256 pendingToken = (userStake[inviter] *
                    (accTokenPerStake - userLastAccTokenPerStake[inviter])) /
                    1e18;
                if (pendingToken > 0) {
                    userStoredToken[inviter] += pendingToken;
                }
            }

            if (hashrate > 0) {
                userStake[inviter] -= hashrate;
                stake -= hashrate;
            }

            userLastAccTokenPerStake[inviter] = accTokenPerStake;
        }
    }

    /**
     * @dev Bind Inviter
     */
    function bindInviter(address inviter) external {
        require(openStatus, "This pool is not opened");
        require(
            userInviter[msg.sender] == address(0),
            "You have already bound the inviter"
        );

        userInviter[msg.sender] = inviter;

        updatePool();
        if (userStake[inviter] > 0) {
            uint256 pendingToken = (userStake[inviter] *
                (accTokenPerStake - userLastAccTokenPerStake[inviter])) / 1e18;
            if (pendingToken > 0) {
                userStoredToken[inviter] += pendingToken;
            }
        }

        uint256 hashrate = hnPool.userStakes(msg.sender, 0);
        if (hashrate > 0) {
            userStake[inviter] += hashrate;
            stake += hashrate;
        }

        userLastAccTokenPerStake[inviter] = accTokenPerStake;

        users.add(msg.sender);
        inviters.add(inviter);
        inviterUsers[inviter].add(msg.sender);

        emit BindInviter(msg.sender, inviter);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken() external {
        updatePool();

        uint256 pendingToken = (userStake[msg.sender] *
            (accTokenPerStake - userLastAccTokenPerStake[msg.sender])) / 1e18;
        uint256 amount = userStoredToken[msg.sender] + pendingToken;
        require(amount > 0, "You have none token to harvest");

        userStoredToken[msg.sender] = 0;
        userLastAccTokenPerStake[msg.sender] = accTokenPerStake;
        userHarvestedToken[msg.sender] += amount;
        harvestedToken += amount;

        hc.mint(msg.sender, amount);

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
     * @dev Get User by Index
     */
    function getUserByIndex(uint256 index) external view returns (address) {
        return users.at(index);
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
        if (block.timestamp <= lastRewardsTime) {
            return;
        }

        if (block.timestamp > lastRewardsTime && stake > 0) {
            uint256 tokenRewards = tokenReleaseSpeed *
                (block.timestamp - lastRewardsTime);
            accTokenPerStake += (tokenRewards * 1e18) / stake;
            releasedToken += tokenRewards;
        }

        lastRewardsTime = block.timestamp;
    }

    /**
     * @dev Get Token Rewards of a User
     */
    function getTokenRewards(address user) public view returns (uint256) {
        uint256 accTokenPerStakeTemp = accTokenPerStake;
        if (block.timestamp > lastRewardsTime && stake > 0) {
            accTokenPerStakeTemp +=
                (tokenReleaseSpeed *
                    (block.timestamp - lastRewardsTime) *
                    1e18) /
                stake;
        }

        return
            userStoredToken[user] +
            ((userStake[user] *
                (accTokenPerStakeTemp - userLastAccTokenPerStake[user])) /
                1e18);
    }
}
