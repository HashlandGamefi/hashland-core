// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";
import "../token/interface/IHC.sol";

/**
 * @title HN Pool Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Stake HN to Harvest HC and Tokens
 */
contract HNPool is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bool public openStatus = false;
    uint256 public lastRewardsTime;

    address[] public tokenAddr;
    uint256[] public tokenReleaseSpeed = [83333333333333333, 3472222222222];

    mapping(uint256 => uint256) public stake;
    mapping(uint256 => uint256) public accTokenPerStake;
    mapping(uint256 => uint256) public releasedToken;
    mapping(uint256 => uint256) public harvestedToken;

    mapping(uint256 => uint256) public airdropedToken;
    mapping(uint256 => uint256) public lastAirdropedToken;
    mapping(uint256 => uint256) public lastAirdropTime;

    mapping(address => mapping(uint256 => uint256)) userStake;
    mapping(address => mapping(uint256 => uint256)) userLastAccTokenPerStake;
    mapping(address => mapping(uint256 => uint256)) userStoredToken;
    mapping(address => mapping(uint256 => uint256)) userHarvestedToken;

    EnumerableSet.AddressSet private users;
    EnumerableSet.UintSet private hnIds;
    mapping(address => EnumerableSet.UintSet) private ownerHnIds;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hnAddr Initialize HN Address
     * @param _tokenAddr Initialize Tokens Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address[] memory _tokenAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        tokenAddr = _tokenAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Token Info
     */
    function setTokenInfo(
        uint256[] calldata _tokenReleaseSpeed,
        address[] calldata _tokenAddr
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _tokenReleaseSpeed.length == _tokenAddr.length,
            "Token Info Length Mismatch"
        );
        tokenReleaseSpeed = _tokenReleaseSpeed;
        tokenAddr = _tokenAddr;
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;
    }

    /**
     * @dev Withdraw Token
     */
    function withdrawToken(
        address _tokenAddr,
        address to,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        IERC20 token = IERC20(_tokenAddr);
        token.transfer(to, amount);
    }

    /**
     * @dev Withdraw NFT
     */
    function withdrawNFT(
        address nftAddr,
        address to,
        uint256 tokenId
    ) external onlyRole(MANAGER_ROLE) {
        IERC721Enumerable nft = IERC721Enumerable(nftAddr);
        nft.safeTransferFrom(address(this), to, tokenId);
    }

    /**
     * @dev Airdrop Token
     */
    function airdropToken(
        uint256[] calldata tokenId,
        uint256[] calldata amount,
        uint256[] calldata releaseSeconds
    ) external onlyRole(MANAGER_ROLE) {
        require(
            tokenId.length == amount.length &&
                tokenId.length == releaseSeconds.length,
            "Token Data Length Mismatch"
        );

        updatePool();
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(tokenId[i] > 0, "Token Id must > 0");
            require(releaseSeconds[i] > 0, "Release Seconds must > 0");

            IERC20 token = IERC20(tokenAddr[tokenId[i]]);
            token.transferFrom(msg.sender, address(this), amount[i]);
            tokenReleaseSpeed[tokenId[i]] = amount[i] / releaseSeconds[i];

            airdropedToken[tokenId[i]] += amount[i];
            lastAirdropedToken[tokenId[i]] = amount[i];
            lastAirdropTime[tokenId[i]] = block.timestamp;
        }
    }

    /**
     * @dev Deposit
     */
    function deposit(uint256 hnId) external {
        require(openStatus, "This Pool is not Opened");

        updatePool();
        for (uint256 i = 0; i < tokenAddr.length; i++) {
            if (userStake[msg.sender][i] > 0) {
                uint256 pendingToken = (userStake[msg.sender][i] *
                    (accTokenPerStake[i] - userLastAccTokenPerStake[msg.sender][i])) /
                    1e18;
                if (pendingToken > 0) {
                    userStoredToken[msg.sender][i] += pendingToken;
                }
            }
        }

        hn.safeTransferFrom(msg.sender, address(this), hnId);
        uint256[] memory hashrates = hn.getHashrates(hnId);
        for (uint256 i = 0; i < hashrates.length; i++) {
            if (hashrates[i] > 0) {
                userStake[msg.sender][i] += hashrates[i];
                stake[i] += hashrates[i];
            }
        }

        for (uint256 i = 0; i < tokenAddr.length; i++) {
            userLastAccTokenPerStake[msg.sender][i] = accTokenPerStake[i];
        }
        hnIds.add(hnId);
        ownerHnIds[msg.sender].add(hnId);
        users.add(msg.sender);

        emit Deposit(msg.sender, hnId);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 hnId) external {
        require(hnIds.contains(hnId), "This HN does Not Exist");
        require(ownerHnIds[msg.sender].contains(hnId), "This HN is not Own");

        updatePool();
        for (uint256 i = 0; i < tokenAddr.length; i++) {
            uint256 pendingToken = (userStake[msg.sender][i] *
                (accTokenPerStake[i] - userLastAccTokenPerStake[msg.sender][i])) / 1e18;
            if (pendingToken > 0) {
                userStoredToken[msg.sender][i] += pendingToken;
            }
        }

        uint256[] memory hashrates = hn.getHashrates(hnId);
        for (uint256 i = 0; i < hashrates.length; i++) {
            if (hashrates[i] > 0) {
                userStake[msg.sender][i] -= hashrates[i];
                stake[i] -= hashrates[i];
            }
        }
        hn.safeTransferFrom(address(this), msg.sender, hnId);

        for (uint256 i = 0; i < tokenAddr.length; i++) {
            userLastAccTokenPerStake[msg.sender][i] = accTokenPerStake[i];
        }
        hnIds.remove(hnId);
        ownerHnIds[msg.sender].remove(hnId);

        emit Withdraw(msg.sender, hnId);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken(uint256 tokenId) external {
        updatePool();
        uint256 pendingToken = (userStake[msg.sender][tokenId] *
            (accTokenPerStake[tokenId] - userLastAccTokenPerStake[msg.sender][tokenId])) /
            1e18;
        uint256 amount = userStoredToken[msg.sender][tokenId] + pendingToken;
        require(amount > 0, "You have No Token to Harvest");

        userStoredToken[msg.sender][tokenId] = 0;
        userLastAccTokenPerStake[msg.sender][tokenId] = accTokenPerStake[tokenId];
        userHarvestedToken[msg.sender][tokenId] += amount;
        harvestedToken[tokenId] += amount;

        if (tokenId == 0) {
            IHC hc = IHC(tokenAddr[tokenId]);
            hc.mint(msg.sender, amount);
        } else {
            IERC20 token = IERC20(tokenAddr[tokenId]);
            token.transfer(msg.sender, amount);
        }

        emit HarvestToken(msg.sender, amount);
    }

    /**
     * @dev Get Token Total Rewards of a User
     */
    function getTokenTotalRewards(address user, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return userHarvestedToken[msg.sender][tokenId] + getTokenRewards(user, tokenId);
    }

    /**
     * @dev Update Pool
     */
    function updatePool() public {
        if (block.timestamp <= lastRewardsTime) {
            return;
        }

        for (uint256 i = 0; i < tokenAddr.length; i++) {
            if (block.timestamp > lastRewardsTime && stake[i] > 0) {
                uint256 tokenRewards = tokenReleaseSpeed[i] *
                    (block.timestamp - lastRewardsTime);
                accTokenPerStake[i] += (tokenRewards * 1e18) / stake[i];
                releasedToken[i] += tokenRewards;
            }
        }

        lastRewardsTime = block.timestamp;
    }

    /**
     * @dev Get Token Rewards of a User
     */
    function getTokenRewards(address user, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 accTokenPerStakeTemp = accTokenPerStake[tokenId];
        if (block.timestamp > lastRewardsTime && stake[tokenId] > 0) {
            accTokenPerStakeTemp +=
                (tokenReleaseSpeed[tokenId] *
                    (block.timestamp - lastRewardsTime) *
                    1e18) /
                stake[tokenId];
        }

        return
            userStoredToken[user][tokenId] +
            ((userStake[user][tokenId] *
                (accTokenPerStakeTemp - userLastAccTokenPerStake[user][tokenId])) /
                1e18);
    }
}
