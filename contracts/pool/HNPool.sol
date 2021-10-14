// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHC.sol";
import "../token/interface/IHN.sol";
import "./interface/IInvitePool.sol";

/**
 * @title HN Pool Contract
 * @author HASHLAND-TEAM
 * @notice This Contract Stake HN to Harvest HC and Tokens
 */
contract HNPool is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;
    IInvitePool public invitePool;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bool public openStatus = false;
    uint256 public maxSlots = 6;
    uint256 public slotBasePrice = 4;
    uint256 public lastRewardsTime;
    address public receivingAddress;

    address[] public tokenAddrs;
    uint256[] public tokenReleaseSpeeds = [12500000000000000, 3472222222222];

    mapping(uint256 => uint256) public stakes;
    mapping(uint256 => uint256) public accTokensPerStake;
    mapping(uint256 => uint256) public releasedTokens;
    mapping(uint256 => uint256) public harvestedTokens;

    mapping(uint256 => uint256) public airdropedTokens;
    mapping(uint256 => uint256) public lastAirdropedTokens;
    mapping(uint256 => uint256) public lastAirdropTimes;

    mapping(address => uint256) public userSlots;
    mapping(address => mapping(uint256 => uint256)) public userStakes;
    mapping(address => mapping(uint256 => uint256))
        public userLastAccTokensPerStake;
    mapping(address => mapping(uint256 => uint256)) public userStoredTokens;
    mapping(address => mapping(uint256 => uint256)) public userHarvestedTokens;

    EnumerableSet.UintSet private hnIds;
    EnumerableSet.AddressSet private users;
    mapping(address => EnumerableSet.UintSet) private userHnIds;

    event Deposit(address indexed user, uint256[] hnIds);
    event Withdraw(address indexed user, uint256[] hnIds);
    event HarvestTokens(
        address indexed user,
        uint256[] tokenIds,
        uint256[] amounts
    );
    event BuySlot(address indexed user, uint256 amount);

    /**
     * @param hnAddr Initialize HN Address
     * @param _tokenAddrs Initialize Tokens Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address[] memory _tokenAddrs,
        address receivingAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        tokenAddrs = _tokenAddrs;

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Tokens Info
     */
    function setTokensInfo(
        address[] calldata _tokenAddrs,
        uint256[] calldata _tokenReleaseSpeeds
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _tokenAddrs.length == _tokenReleaseSpeeds.length,
            "Tokens Info Length Mismatch"
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
     * @dev Set Max Slots
     */
    function setMaxSlots(uint256 slots) external onlyRole(MANAGER_ROLE) {
        maxSlots = slots;
    }

    /**
     * @dev Set Slot Base Price
     */
    function setSlotBasePrice(uint256 price) external onlyRole(MANAGER_ROLE) {
        slotBasePrice = price;
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
     * @dev Set Invite Pool Address
     */
    function setInvitePoolAddress(address invitePoolAddr)
        external
        onlyRole(MANAGER_ROLE)
    {
        invitePool = IInvitePool(invitePoolAddr);
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
     * @dev Airdrop Tokens
     */
    function airdropTokens(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        uint256[] calldata releaseSeconds
    ) external onlyRole(MANAGER_ROLE) {
        require(
            tokenIds.length == amounts.length &&
                tokenIds.length == releaseSeconds.length,
            "Tokens Data Length Mismatch"
        );

        updatePool();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] > 0, "Token Id must > 0");
            require(releaseSeconds[i] > 0, "Release Seconds must > 0");

            IERC20 token = IERC20(tokenAddrs[tokenIds[i]]);
            token.transferFrom(msg.sender, address(this), amounts[i]);
            tokenReleaseSpeeds[tokenIds[i]] = amounts[i] / releaseSeconds[i];

            airdropedTokens[tokenIds[i]] += amounts[i];
            lastAirdropedTokens[tokenIds[i]] = amounts[i];
            lastAirdropTimes[tokenIds[i]] = block.timestamp;
        }
    }

    /**
     * @dev Deposit
     */
    function deposit(uint256[] calldata _hnIds) external {
        require(openStatus, "This Pool is not Opened");
        require(
            _hnIds.length <= getUserLeftSlots(msg.sender),
            "Not Enough Slots"
        );

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

        uint256 hcHashrate;
        for (uint256 i = 0; i < _hnIds.length; i++) {
            hn.safeTransferFrom(msg.sender, address(this), _hnIds[i]);
            uint256[] memory hashrates = hn.getHashrates(_hnIds[i]);
            for (uint256 j = 0; j < hashrates.length; j++) {
                if (hashrates[j] > 0) {
                    userStakes[msg.sender][j] += hashrates[j];
                    stakes[j] += hashrates[j];
                }
            }
            hnIds.add(_hnIds[i]);
            userHnIds[msg.sender].add(_hnIds[i]);
            if (hashrates[0] > 0) hcHashrate += hashrates[0];
        }

        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                userLastAccTokensPerStake[msg.sender][i] = accTokensPerStake[i];
            }
        }
        users.add(msg.sender);

        invitePool.depositInviter(msg.sender, hcHashrate);

        emit Deposit(msg.sender, _hnIds);
    }

    /**
     * @dev Withdraw
     */
    function withdraw(uint256[] calldata _hnIds) external {
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

        uint256 hcHashrate;
        for (uint256 i = 0; i < _hnIds.length; i++) {
            require(hnIds.contains(_hnIds[i]), "This HN does Not Exist");
            require(
                userHnIds[msg.sender].contains(_hnIds[i]),
                "This HN is not Own"
            );

            uint256[] memory hashrates = hn.getHashrates(_hnIds[i]);
            for (uint256 j = 0; j < hashrates.length; j++) {
                if (hashrates[j] > 0) {
                    userStakes[msg.sender][j] -= hashrates[j];
                    stakes[j] -= hashrates[j];
                }
            }
            hnIds.remove(_hnIds[i]);
            userHnIds[msg.sender].remove(_hnIds[i]);
            hn.safeTransferFrom(address(this), msg.sender, _hnIds[i]);
            if (hashrates[0] > 0) hcHashrate += hashrates[0];
        }

        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            if (userStakes[msg.sender][i] > 0) {
                userLastAccTokensPerStake[msg.sender][i] = accTokensPerStake[i];
            }
        }

        invitePool.withdrawInviter(msg.sender, hcHashrate);

        emit Withdraw(msg.sender, _hnIds);
    }

    /**
     * @dev Harvest Tokens
     */
    function harvestTokens(uint256[] calldata tokenIds) external {
        updatePool();

        uint256[] memory amounts = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 pendingToken = (userStakes[msg.sender][tokenIds[i]] *
                (accTokensPerStake[tokenIds[i]] -
                    userLastAccTokensPerStake[msg.sender][tokenIds[i]])) / 1e18;
            amounts[i] =
                userStoredTokens[msg.sender][tokenIds[i]] +
                pendingToken;

            if (amounts[i] > 0) {
                userStoredTokens[msg.sender][tokenIds[i]] = 0;
                userLastAccTokensPerStake[msg.sender][
                    tokenIds[i]
                ] = accTokensPerStake[tokenIds[i]];
                userHarvestedTokens[msg.sender][tokenIds[i]] += amounts[i];
                harvestedTokens[tokenIds[i]] += amounts[i];

                if (tokenIds[i] == 0) {
                    IHC hc = IHC(tokenAddrs[tokenIds[i]]);
                    hc.mint(msg.sender, amounts[i]);
                } else {
                    IERC20 token = IERC20(tokenAddrs[tokenIds[i]]);
                    token.transfer(msg.sender, amounts[i]);
                }
            }
        }

        emit HarvestTokens(msg.sender, tokenIds, amounts);
    }

    /**
     * @dev Buy Slot
     */
    function buySlot() external {
        require(
            getUserSlots(msg.sender) < maxSlots,
            "Slots has Reached the Limit"
        );

        uint256 amount = getUserSlotPrice(msg.sender);
        IHC hc = IHC(tokenAddrs[0]);
        hc.transferFrom(msg.sender, receivingAddress, amount);
        userSlots[msg.sender]++;

        emit BuySlot(msg.sender, amount);
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
            userHarvestedTokens[user][tokenId] + getTokenRewards(user, tokenId);
    }

    /**
     * @dev Get Tokens Info
     */
    function getTokensInfo()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        return (tokenAddrs, tokenReleaseSpeeds);
    }

    /**
     * @dev Get HnIds Length
     */
    function getHnIdsLength() external view returns (uint256) {
        return hnIds.length();
    }

    /**
     * @dev Get HnIds by Size
     */
    function getHnIdsBySize(uint256 cursor, uint256 size)
        external
        view
        returns (uint256[] memory, uint256)
    {
        uint256 length = size;
        if (length > hnIds.length() - cursor) {
            length = hnIds.length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = hnIds.at(cursor + i);
        }

        return (values, cursor + length);
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
     * @dev Get User HnIds Length
     */
    function getUserHnIdsLength(address user) external view returns (uint256) {
        return userHnIds[user].length();
    }

    /**
     * @dev Get User HnIds by Size
     */
    function getUserHnIdsBySize(
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > userHnIds[user].length() - cursor) {
            length = userHnIds[user].length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = userHnIds[user].at(cursor + i);
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
     * @dev Get User Slots
     */
    function getUserSlots(address user) public view returns (uint256) {
        return 1 + userSlots[user];
    }

    /**
     * @dev Get User Left Slots
     */
    function getUserLeftSlots(address user) public view returns (uint256) {
        return getUserSlots(user) - userHnIds[user].length();
    }

    /**
     * @dev Get User Slot Price
     */
    function getUserSlotPrice(address user) public view returns (uint256) {
        return slotBasePrice**getUserSlots(user) * 1e18;
    }
}
