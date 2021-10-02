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

    IHN public hn;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct UserInfo {
        uint256[] stake;
        uint256[] lastAccTokenPerStake;
        uint256[] storedToken;
        uint256[] harvestedToken;
    }

    mapping(address => UserInfo) public userInfo;

    bool public openStatus = false;
    uint256[] public stake;
    uint256[] public lastRewardsTime;

    uint256[] public accTokenPerStake;
    uint256[] public tokenReleaseSpeed = [83333333333333333, 3472222222222];
    address[] public tokenAddr;
    uint256[] public releasedToken;
    uint256[] public harvestedToken;

    uint256[] public airdropedToken;
    uint256[] public lastAirdropedToken;
    uint256[] public lastAirdropTime;

    EnumerableSet.AddressSet private users;

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
        address[] calldata _tokenAddr,
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

        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        for (uint256 i = 0; i < user.stake.length; i++) {
            if (user.stake[i] > 0) {
                uint256 pendingToken = (user.stake[i] *
                    (accTokenPerStake[i] - user.lastAccTokenPerStake[i])) /
                    1e18;
                if (pendingToken > 0) {
                    user.storedToken[i] += pendingToken;
                }
            }
        }

        hn.safeTransferFrom(msg.sender, address(this), hnId);

        uint256[] memory hashrates = hn.getHashrates(hnId);
        for (uint256 i = 0; i < hashrates.length; i++) {
            user.stake[i] += hashrates[i];
            stake[i] += hashrates[i];
        }
        for (uint256 i = 0; i < user.stake.length; i++) {
            user.lastAccTokenPerStake[i] = accTokenPerStake[i];
        }
        users.add(msg.sender);

        emit Deposit(msg.sender, hnId);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.stake >= amount, "You have not Enough ETHST to Withdraw");

        updatePool();
        uint256 pendingET = (user.stake *
            (accETPerStake - user.lastAccETPerStake)) / 1e18;
        if (pendingET > 0) {
            user.storedET += pendingET;
        }
        uint256 pendingETH = (user.stake *
            (accETHPerStake - user.lastAccETHPerStake)) / 1e18;
        if (pendingETH > 0) {
            user.storedETH += pendingETH;
        }
        if (amount > 0) {
            user.stake -= amount;
            stake -= amount;
            ethstToken.transfer(msg.sender, amount);
        }

        user.lastAccETPerStake = accETPerStake;
        user.lastAccETHPerStake = accETHPerStake;

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Harvest ET
     */
    function harvestET() external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pendingET = (user.stake *
            (accETPerStake - user.lastAccETPerStake)) / 1e18;
        uint256 amount = user.storedET + pendingET;
        require(amount > 0, "You have No ET to Harvest");

        user.storedET = 0;
        user.lastAccETPerStake = accETPerStake;
        user.harvestedET += amount;
        harvestedET += amount;

        if (isTransferMode == true) {
            etToken.transfer(msg.sender, amount);
        } else {
            etToken.mint(msg.sender, amount);
        }

        emit HarvestET(msg.sender, amount);
    }

    /**
     * @dev Harvest ETH
     */
    function harvestETH() external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pendingETH = (user.stake *
            (accETHPerStake - user.lastAccETHPerStake)) / 1e18;
        uint256 amount = user.storedETH + pendingETH;
        require(amount > 0, "You have No ETH to Harvest");

        user.storedETH = 0;
        user.lastAccETHPerStake = accETHPerStake;
        user.harvestedETH += amount;
        harvestedETH += amount;

        ethToken.transfer(msg.sender, amount);

        emit HarvestETH(msg.sender, amount);
    }

    /**
     * @dev Get ET Total Rewards of a User
     */
    function getETTotalRewards(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return user.harvestedET + getETRewards(_user);
    }

    /**
     * @dev Get ETH Total Rewards of a User
     */
    function getETHTotalRewards(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return user.harvestedETH + getETHRewards(_user);
    }

    /**
     * @dev Update Pool
     */
    function updatePool() public {
        if (block.timestamp <= lastRewardsTime) {
            return;
        }

        if (block.timestamp > lastRewardsTime && stake > 0) {
            uint256 etRewards = etReleaseSpeed *
                (block.timestamp - lastRewardsTime);
            accETPerStake += (etRewards * 1e18) / stake;
            releasedET += etRewards;
            uint256 ethRewards = ethReleaseSpeed *
                (block.timestamp - lastRewardsTime);
            accETHPerStake += (ethRewards * 1e18) / stake;
            releasedETH += ethRewards;
        }
        lastRewardsTime = block.timestamp;

        if (isTransferMode == true) {
            uint256 lastAutoMintTokens = etToken.supplyTokens() /
                (etToken.releaseRatio() - 1);
            uint256 newSpeed = (lastAutoMintTokens * poolWeight) / 100 / 86400;
            if (etReleaseSpeed != newSpeed) etReleaseSpeed = newSpeed;
        }
    }

    /**
     * @dev Get ET Rewards of a User
     */
    function getETRewards(address _user) public view returns (uint256) {
        uint256 accETPerStakeTemp = accETPerStake;
        if (block.timestamp > lastRewardsTime && stake > 0) {
            accETPerStakeTemp +=
                (etReleaseSpeed * (block.timestamp - lastRewardsTime) * 1e18) /
                stake;
        }

        UserInfo memory user = userInfo[_user];
        return
            user.storedET +
            ((user.stake * (accETPerStakeTemp - user.lastAccETPerStake)) /
                1e18);
    }

    /**
     * @dev Get ETH Rewards of a User
     */
    function getETHRewards(address _user) public view returns (uint256) {
        uint256 accETHPerStakeTemp = accETHPerStake;
        if (block.timestamp > lastRewardsTime && stake > 0) {
            accETHPerStakeTemp +=
                (ethReleaseSpeed * (block.timestamp - lastRewardsTime) * 1e18) /
                stake;
        }

        UserInfo memory user = userInfo[_user];
        return
            user.storedETH +
            ((user.stake * (accETHPerStakeTemp - user.lastAccETHPerStake)) /
                1e18);
    }
}
