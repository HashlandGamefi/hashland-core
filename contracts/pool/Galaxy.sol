// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IPLANET.sol";
import "../token/interface/IALIEN.sol";

/**
 * @title Galaxy Contract
 * @author ETHST-TEAM
 * @notice In this Contract ALIEN can Mint on the PLANET
 */
contract Galaxy is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.UintSet;

    IPLANET public planetNFT;
    IALIEN public alienNFT;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public startTime;
    uint256 public totalRemain;
    uint256 public storedRemain;
    uint256 public totalBalance;

    mapping(uint256 => uint256) public planetRewards;
    mapping(uint256 => uint256) public planetTotalRewards;
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public userTotalRewards;

    EnumerableSet.UintSet private planetIds;
    mapping(address => EnumerableSet.UintSet) private ownerPlanetIds;

    event DepositPlanet(
        address indexed user,
        uint256 indexed planetId,
        uint256 remain
    );
    event WithdrawPlanet(address indexed user, uint256 indexed planetId);
    event Mint(
        address indexed user,
        uint256 indexed planetId,
        uint256 indexed alienId,
        uint256 planetReward,
        uint256 userReward
    );
    event HarvestUserRewards(address indexed user, uint256 amount);
    event HarvestPlanetRewards(
        address indexed user,
        uint256 indexed planetId,
        uint256 amount
    );

    /**
     * @param planetAddr Initialize PLANET NFT Address
     * @param alienAddr Initialize ALIEN NFT Address\
     * @param manager Initialize Manager Role
     * @param _startTime Initialize Start Timestamp, Should be at 15:00 on a Certain Day
     */
    constructor(
        address planetAddr,
        address alienAddr,
        address manager,
        uint256 _startTime
    ) {
        planetNFT = IPLANET(planetAddr);
        alienNFT = IALIEN(alienAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);

        startTime = _startTime;
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
     * @dev Deposit Planet
     */
    function depositPlanet(uint256 planetId) external {
        require(block.timestamp >= startTime, "This Galaxy has not Opened yet");
        uint256 remain = planetNFT.getPlanetRemain(planetId);
        require(remain > 0, "This Planet's Resources are Exhausted");
        require(getGalaxyBalance() >= remain, "Galaxy has Not Enough Balance");

        planetNFT.safeTransferFrom(msg.sender, address(this), planetId);

        planetIds.add(planetId);
        ownerPlanetIds[msg.sender].add(planetId);
        totalRemain += remain;
        storedRemain += remain;

        emit DepositPlanet(msg.sender, planetId, remain);
    }

    /**
     * @dev Withdraw Planet
     */
    function withdrawPlanet(uint256 planetId) external {
        require(planetIds.contains(planetId), "This Planet does Not Exist");
        require(
            ownerPlanetIds[msg.sender].contains(planetId),
            "This Planet is not Own"
        );
        require(
            planetNFT.getPlanetRemain(planetId) == 0,
            "Can Only be Withdrawn after Resources are Exhausted"
        );
        require(
            planetRewards[planetId] == 0,
            "You Should Harvest Rewards First"
        );

        planetNFT.safeTransferFrom(address(this), msg.sender, planetId);

        planetIds.remove(planetId);
        ownerPlanetIds[msg.sender].remove(planetId);

        emit WithdrawPlanet(msg.sender, planetId);
    }

    /**
     * @dev Mint
     */
    function mint(uint256 planetId, uint256 alienId)
        external
        returns (uint256)
    {
        require(block.timestamp >= startTime, "This Galaxy has not Opened yet");
        require(planetIds.contains(planetId), "This Planet does Not Exist");
        require(
            alienNFT.ownerOf(alienId) == msg.sender,
            "This Alien is not Own"
        );
        require(
            planetNFT.getPlanetRemain(planetId) > 0,
            "This Planet's Resources are Exhausted"
        );
        require(
            alienNFT.getAlienMintCoolDown(alienId) == 0,
            "Mint Skill is Still Cooling"
        );
        require(
            planetNFT.getPlanetGalaxy(planetId) ==
                alienNFT.getAlienGalaxy(alienId),
            "The Galaxy should be the Same"
        );

        alienNFT.mint(alienId);

        uint256 planetReward;
        uint256 userReward;
        uint256 rate = planetNFT.getPlanetMintRate(planetId);
        rate += alienNFT.getAlienMintRate(alienId);
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    block.timestamp,
                    totalRemain,
                    storedRemain,
                    totalBalance,
                    planetTotalRewards[planetId],
                    userTotalRewards[msg.sender],
                    planetId,
                    alienId,
                    rate
                )
            )
        ) % 1e4;

        if (random < rate) {
            uint256 amount = (planetNFT.getPlanetSupply(planetId) *
                alienNFT.getAlienMintRatio(alienId)) / 1e4;
            uint256 mintAmount = planetNFT.mintPlanet(planetId, amount);
            planetReward = (mintAmount * 30) / 100;
            userReward = (mintAmount * 70) / 100;
            planetRewards[planetId] += planetReward;
            planetTotalRewards[planetId] += planetReward;
            userRewards[msg.sender] += userReward;
            userTotalRewards[msg.sender] += userReward;
        }

        emit Mint(msg.sender, planetId, alienId, planetReward, userReward);

        return userReward;
    }

    /**
     * @dev Harvest User Rewards
     */
    function harvestUserRewards() external {
        uint256 amount = userRewards[msg.sender];
        require(amount > 0, "You have No Rewards to Harvest");

        userRewards[msg.sender] = 0;
        storedRemain -= amount;
        payable(msg.sender).transfer(amount);

        emit HarvestUserRewards(msg.sender, amount);
    }

    /**
     * @dev Harvest Planet Rewards
     */
    function harvestPlanetRewards(uint256 planetId) external {
        require(planetIds.contains(planetId), "This Planet does Not Exist");
        require(
            ownerPlanetIds[msg.sender].contains(planetId),
            "This Planet is not Own"
        );
        uint256 amount = planetRewards[planetId];
        require(amount > 0, "You have No Rewards to Harvest");

        planetRewards[planetId] = 0;
        storedRemain -= amount;
        payable(msg.sender).transfer(amount);

        emit HarvestPlanetRewards(msg.sender, planetId, amount);
    }

    /**
     * @dev Get Planet Ids Length
     */
    function getPlanetIdsLength() external view returns (uint256) {
        return planetIds.length();
    }

    /**
     * @dev Get Planet Id by Index
     */
    function getPlanetIdByIndex(uint256 index) external view returns (uint256) {
        return planetIds.at(index);
    }

    /**
     * @dev Get Planet Ids
     */
    function getPlanetIds() external view returns (uint256[] memory) {
        return planetIds.values();
    }

    /**
     * @dev Get Owner Planet Ids Length
     */
    function getOwnerPlanetIdsLength(address owner)
        external
        view
        returns (uint256)
    {
        return ownerPlanetIds[owner].length();
    }

    /**
     * @dev Get Owner Planet Id by Index
     */
    function getOwnerPlanetIdByIndex(address owner, uint256 index)
        external
        view
        returns (uint256)
    {
        return ownerPlanetIds[owner].at(index);
    }

    /**
     * @dev Get Owner Planet Ids
     */
    function getOwnerPlanetIds(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerPlanetIds[owner].values();
    }

    /**
     * @dev Get Galaxy Balance
     */
    function getGalaxyBalance() public view returns (uint256) {
        return
            address(this).balance > storedRemain
                ? address(this).balance - storedRemain
                : 0;
    }

    receive() external payable {
        totalBalance += msg.value;
    }
}
