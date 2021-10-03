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

    address[] public tokenAddrs;
    uint256[] public tokenReleaseSpeeds = [83333333333333333, 3472222222222];

    mapping(uint256 => uint256) public stakes;
    mapping(uint256 => uint256) public accTokensPerStake;
    mapping(uint256 => uint256) public releasedTokens;
    mapping(uint256 => uint256) public harvestedTokens;

    mapping(uint256 => uint256) public airdropedTokens;
    mapping(uint256 => uint256) public lastAirdropedTokens;
    mapping(uint256 => uint256) public lastAirdropTimes;

    mapping(address => mapping(uint256 => uint256)) userStakes;
    mapping(address => mapping(uint256 => uint256)) userLastAccTokensPerStake;
    mapping(address => mapping(uint256 => uint256)) userStoredTokens;
    mapping(address => mapping(uint256 => uint256)) userHarvestedTokens;

    EnumerableSet.UintSet private hnIds;
    EnumerableSet.AddressSet private users;
    mapping(address => EnumerableSet.UintSet) private userHnIds;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event HarvestToken(address indexed user, uint256 amount);

    /**
     * @param hnAddr Initialize HN Address
     * @param _tokenAddrs Initialize Tokens Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address[] memory _tokenAddrs,
        address manager
    ) {
        hn = IHN(hnAddr);
        tokenAddrs = _tokenAddrs;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Token Info
     */
    function setTokenInfo(
        address[] calldata _tokenAddrs,
        uint256[] calldata _tokenReleaseSpeeds
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _tokenAddrs.length == _tokenReleaseSpeeds.length,
            "Token Info Length Mismatch"
        );
        tokenAddrs = _tokenAddrs;
        tokenReleaseSpeeds = _tokenReleaseSpeeds;
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
        address _tokenAddrs,
        address to,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        IERC20 token = IERC20(_tokenAddrs);
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

            IERC20 token = IERC20(tokenAddrs[tokenId[i]]);
            token.transferFrom(msg.sender, address(this), amount[i]);
            tokenReleaseSpeeds[tokenId[i]] = amount[i] / releaseSeconds[i];

            airdropedTokens[tokenId[i]] += amount[i];
            lastAirdropedTokens[tokenId[i]] = amount[i];
            lastAirdropTimes[tokenId[i]] = block.timestamp;
        }
    }

    /**
     * @dev Deposit
     */
    function deposit(uint256 hnId) external {
        require(openStatus, "This Pool is not Opened");

        updatePool();
        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                uint256 pendingToken = (userStakes[msg.sender][i] *
                    (accTokensPerStake[i] -
                        userLastAccTokensPerStake[msg.sender][i])) / 1e18;
                if (pendingToken > 0) {
                    userStoredTokens[msg.sender][i] += pendingToken;
                }
            }
        }

        hn.safeTransferFrom(msg.sender, address(this), hnId);
        uint256[] memory hashrates = hn.getHashrates(hnId);
        for (uint256 i = 0; i < hashrates.length; i++) {
            if (hashrates[i] > 0) {
                userStakes[msg.sender][i] += hashrates[i];
                stakes[i] += hashrates[i];
            }
        }

        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                userLastAccTokensPerStake[msg.sender][i] = accTokensPerStake[i];
            }
        }
        hnIds.add(hnId);
        userHnIds[msg.sender].add(hnId);
        users.add(msg.sender);

        emit Deposit(msg.sender, hnId);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 hnId) external {
        require(hnIds.contains(hnId), "This HN does Not Exist");
        require(userHnIds[msg.sender].contains(hnId), "This HN is not Own");

        updatePool();
        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                uint256 pendingToken = (userStakes[msg.sender][i] *
                    (accTokensPerStake[i] -
                        userLastAccTokensPerStake[msg.sender][i])) / 1e18;
                if (pendingToken > 0) {
                    userStoredTokens[msg.sender][i] += pendingToken;
                }
            }
        }

        uint256[] memory hashrates = hn.getHashrates(hnId);
        for (uint256 i = 0; i < hashrates.length; i++) {
            if (hashrates[i] > 0) {
                userStakes[msg.sender][i] -= hashrates[i];
                stakes[i] -= hashrates[i];
            }
        }
        hn.safeTransferFrom(address(this), msg.sender, hnId);

        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                userLastAccTokensPerStake[msg.sender][i] = accTokensPerStake[i];
            }
        }
        hnIds.remove(hnId);
        userHnIds[msg.sender].remove(hnId);

        emit Withdraw(msg.sender, hnId);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken(uint256 tokenId) external {
        updatePool();
        uint256 pendingToken = (userStakes[msg.sender][tokenId] *
            (accTokensPerStake[tokenId] -
                userLastAccTokensPerStake[msg.sender][tokenId])) / 1e18;
        uint256 amount = userStoredTokens[msg.sender][tokenId] + pendingToken;
        require(amount > 0, "You have No Token to Harvest");

        userStoredTokens[msg.sender][tokenId] = 0;
        userLastAccTokensPerStake[msg.sender][tokenId] = accTokensPerStake[
            tokenId
        ];
        userHarvestedTokens[msg.sender][tokenId] += amount;
        harvestedTokens[tokenId] += amount;

        if (tokenId == 0) {
            IHC hc = IHC(tokenAddrs[tokenId]);
            hc.mint(msg.sender, amount);
        } else {
            IERC20 token = IERC20(tokenAddrs[tokenId]);
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
        return
            userHarvestedTokens[msg.sender][tokenId] +
            getTokenRewards(user, tokenId);
    }

    /**
     * @dev Get Token Info
     */
    function getTokenInfo()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        return (tokenAddrs, tokenReleaseSpeeds);
    }

    /**
     * @dev Update Pool
     */
    function updatePool() public {
        if (block.timestamp <= lastRewardsTime) {
            return;
        }

        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (block.timestamp > lastRewardsTime && stakes[i] > 0) {
                uint256 tokenRewards = tokenReleaseSpeeds[i] *
                    (block.timestamp - lastRewardsTime);
                accTokensPerStake[i] += (tokenRewards * 1e18) / stakes[i];
                releasedTokens[i] += tokenRewards;
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
        uint256 accTokensPerStakeTemp = accTokensPerStake[tokenId];
        if (block.timestamp > lastRewardsTime && stakes[tokenId] > 0) {
            accTokensPerStakeTemp +=
                (tokenReleaseSpeeds[tokenId] *
                    (block.timestamp - lastRewardsTime) *
                    1e18) /
                stakes[tokenId];
        }

        return
            userStoredTokens[user][tokenId] +
            ((userStakes[user][tokenId] *
                (accTokensPerStakeTemp -
                    userLastAccTokensPerStake[user][tokenId])) / 1e18);
    }

    /**
     * @dev Get HnIds Length
     */
    function getHnIdsLength() external view returns (uint256) {
        return hnIds.length();
    }

    /**
     * @dev Get HnId by Index
     */
    function getHnIdByIndex(uint256 index) external view returns (uint256) {
        return hnIds.at(index);
    }

    /**
     * @dev Get HnIds
     */
    function getHnIds() external view returns (uint256[] memory) {
        return hnIds.values();
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
     * @dev Get User HnIds Length
     */
    function getUserHnIdsLength(address user) external view returns (uint256) {
        return userHnIds[user].length();
    }

    /**
     * @dev Get User HnId by Index
     */
    function getUserHnIdByIndex(address user, uint256 index)
        external
        view
        returns (uint256)
    {
        return userHnIds[user].at(index);
    }

    /**
     * @dev Get User HnIds
     */
    function getUserHnIds(address user)
        external
        view
        returns (uint256[] memory)
    {
        return userHnIds[user].values();
    }
}
