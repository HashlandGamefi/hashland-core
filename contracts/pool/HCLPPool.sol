// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHC.sol";

/**
 * @title HC LP Pool Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can stake HC LP to harvest HC
 */
contract HCLPPool is AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IHC public hc;
    IERC20 public lpToken;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bool public openStatus = false;
    uint256 public multiplier = 100;

    uint256 public stake;
    uint256 public accTokenPerStake;
    uint256 public releasedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public userStake;
    mapping(address => uint256) public userLastAccTokenPerStake;
    mapping(address => uint256) public userStoredToken;
    mapping(address => uint256) public userHarvestedToken;

    EnumerableSet.AddressSet private users;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hcAddr Initialize HC Address
     * @param hclpAddr Initialize HC LP Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hcAddr,
        address hclpAddr,
        address manager
    ) {
        hc = IHC(hcAddr);
        lpToken = IERC20(hclpAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Withdraw Token
     */
    function withdrawToken(
        address _tokenAddrs,
        address to,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        IERC20 token = IERC20(_tokenAddrs);
        token.transfer(to, amount);
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;
    }

    /**
     * @dev Set Multiplier
     */
    function setMultiplier(uint256 _multiplier)
        external
        onlyRole(MANAGER_ROLE)
    {
        multiplier = _multiplier;
    }

    /**
     * @dev Deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(openStatus, "This pool is not opened");

        updatePool();

        if (userStake[msg.sender] > 0) {
            uint256 pendingToken = (userStake[msg.sender] *
                (accTokenPerStake - userLastAccTokenPerStake[msg.sender])) /
                1e18;
            if (pendingToken > 0) {
                userStoredToken[msg.sender] += pendingToken;
            }
        }

        if (amount > 0) {
            lpToken.transferFrom(msg.sender, address(this), amount);
            userStake[msg.sender] += amount;
            stake += amount;
        }

        userLastAccTokenPerStake[msg.sender] = accTokenPerStake;
        users.add(msg.sender);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(
            userStake[msg.sender] >= amount,
            "Not enough HC LP to withdraw"
        );

        updatePool();

        uint256 pendingToken = (userStake[msg.sender] *
            (accTokenPerStake - userLastAccTokenPerStake[msg.sender])) / 1e18;
        if (pendingToken > 0) {
            userStoredToken[msg.sender] += pendingToken;
        }

        if (amount > 0) {
            userStake[msg.sender] -= amount;
            stake -= amount;
            lpToken.transfer(msg.sender, amount);
        }

        userLastAccTokenPerStake[msg.sender] = accTokenPerStake;

        emit Withdraw(msg.sender, amount);
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

        hc.transfer(msg.sender, amount);

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
        if (stake > 0) {
            uint256 amount = (hc.harvestToken() * multiplier) / 100;
            accTokenPerStake += (amount * 1e18) / stake;
            releasedToken += amount;
        }
    }

    /**
     * @dev Get Token Rewards of a User
     */
    function getTokenRewards(address user) public view returns (uint256) {
        uint256 accTokenPerStakeTemp = accTokenPerStake;
        if (stake > 0) {
            accTokenPerStakeTemp +=
                (((hc.getTokenRewards(address(this)) * multiplier) / 100) *
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
