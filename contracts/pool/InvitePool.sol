// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHC.sol";
import "../pool/interface/IHNPool.sol";

/**
 * @title Invite Pool Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can bind inviters and inviters can harvest HC
 */
contract InvitePool is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IHC;
    using EnumerableSet for EnumerableSet.AddressSet;

    IHC public hc;
    IHNPool public hnPool;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant HNPOOL_ROLE = keccak256("HNPOOL_ROLE");

    bool public openStatus = false;

    uint256 public stake;
    uint256 public accTokenPerStake;
    uint256 public releasedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public inviterStake;
    mapping(address => uint256) public inviterLastAccTokenPerStake;
    mapping(address => uint256) public inviterStoredToken;
    mapping(address => uint256) public inviterHarvestedToken;

    EnumerableSet.AddressSet private users;
    mapping(address => address) public userInviter;

    EnumerableSet.AddressSet private inviters;
    mapping(address => EnumerableSet.AddressSet) private inviterUsers;

    event SetOpenStatus(bool status);
    event BindInviter(address indexed user, address indexed inviter);
    event HarvestToken(address indexed inviter, uint256 amount);

    /**
     * @param hcAddr Initialize HC Address
     * @param hnPoolAddr Initialize HNPool Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hcAddr,
        address hnPoolAddr,
        address manager
    ) {
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

        emit SetOpenStatus(status);
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
            if (inviterStake[inviter] > 0) {
                uint256 pendingToken = (inviterStake[inviter] *
                    (accTokenPerStake - inviterLastAccTokenPerStake[inviter])) /
                    1e18;
                if (pendingToken > 0) {
                    inviterStoredToken[inviter] += pendingToken;
                }
            }

            if (hashrate > 0) {
                inviterStake[inviter] += hashrate;
                stake += hashrate;
            }

            inviterLastAccTokenPerStake[inviter] = accTokenPerStake;
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
            if (inviterStake[inviter] > 0) {
                uint256 pendingToken = (inviterStake[inviter] *
                    (accTokenPerStake - inviterLastAccTokenPerStake[inviter])) /
                    1e18;
                if (pendingToken > 0) {
                    inviterStoredToken[inviter] += pendingToken;
                }
            }

            if (hashrate > 0) {
                inviterStake[inviter] -= hashrate;
                stake -= hashrate;
            }

            inviterLastAccTokenPerStake[inviter] = accTokenPerStake;
        }
    }

    /**
     * @dev Bind Inviter
     */
    function bindInviter(address inviter) external nonReentrant {
        require(openStatus, "This pool is not opened");
        require(
            userInviter[msg.sender] == address(0),
            "You have already bound the inviter"
        );
        require(inviter != msg.sender, "You cannot bind yourself");
        require(
            userInviter[inviter] != msg.sender,
            "Your inviter's inviter cannot be yourself"
        );

        userInviter[msg.sender] = inviter;

        updatePool();

        if (inviterStake[inviter] > 0) {
            uint256 pendingToken = (inviterStake[inviter] *
                (accTokenPerStake - inviterLastAccTokenPerStake[inviter])) /
                1e18;
            if (pendingToken > 0) {
                inviterStoredToken[inviter] += pendingToken;
            }
        }

        uint256 hashrate = hnPool.userStakes(msg.sender, 0);
        if (hashrate > 0) {
            inviterStake[inviter] += hashrate;
            stake += hashrate;
        }

        inviterLastAccTokenPerStake[inviter] = accTokenPerStake;

        inviters.add(inviter);
        users.add(msg.sender);
        inviterUsers[inviter].add(msg.sender);

        emit BindInviter(msg.sender, inviter);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken() external nonReentrant {
        updatePool();

        uint256 pendingToken = (inviterStake[msg.sender] *
            (accTokenPerStake - inviterLastAccTokenPerStake[msg.sender])) /
            1e18;
        uint256 amount = inviterStoredToken[msg.sender] + pendingToken;
        require(amount > 0, "You have none token to harvest");

        inviterStoredToken[msg.sender] = 0;
        inviterLastAccTokenPerStake[msg.sender] = accTokenPerStake;
        inviterHarvestedToken[msg.sender] += amount;
        harvestedToken += amount;

        hc.safeTransfer(msg.sender, amount);

        emit HarvestToken(msg.sender, amount);
    }

    /**
     * @dev Get Token Total Rewards of a Inviter
     */
    function getTokenTotalRewards(address inviter)
        external
        view
        returns (uint256)
    {
        return inviterHarvestedToken[inviter] + getTokenRewards(inviter);
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
     * @dev Get Inviters Length
     */
    function getInvitersLength() external view returns (uint256) {
        return inviters.length();
    }

    /**
     * @dev Get Inviters by Size
     */
    function getInvitersBySize(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory, uint256)
    {
        uint256 length = size;
        if (length > inviters.length() - cursor) {
            length = inviters.length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = inviters.at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Inviter Users Length
     */
    function getInviterUsersLength(address inviter)
        external
        view
        returns (uint256)
    {
        return inviterUsers[inviter].length();
    }

    /**
     * @dev Get Inviter Users by Size
     */
    function getInviterUsersBySize(
        address inviter,
        uint256 cursor,
        uint256 size
    ) external view returns (address[] memory, uint256) {
        uint256 length = size;
        if (length > inviterUsers[inviter].length() - cursor) {
            length = inviterUsers[inviter].length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = inviterUsers[inviter].at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Update Pool
     */
    function updatePool() public {
        if (stake > 0) {
            uint256 amount = hc.harvestToken();
            accTokenPerStake += (amount * 1e18) / stake;
            releasedToken += amount;
        }
    }

    /**
     * @dev Get Token Rewards of a Inviter
     */
    function getTokenRewards(address inviter) public view returns (uint256) {
        uint256 accTokenPerStakeTemp = accTokenPerStake;
        if (stake > 0) {
            accTokenPerStakeTemp +=
                (hc.getTokenRewards(address(this)) * 1e18) /
                stake;
        }

        return
            inviterStoredToken[inviter] +
            ((inviterStake[inviter] *
                (accTokenPerStakeTemp - inviterLastAccTokenPerStake[inviter])) /
                1e18);
    }
}
