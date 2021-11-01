// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Hashland Coin
 * @author HASHLAND-TEAM
 * @notice This Contract Supply HC
 */
contract HC is ERC20, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public constant blockPerDay = 28800;
    uint256 public constant blockPerQuarter = (blockPerDay * 365) / 4;
    uint256 public constant initTokenPerDay = 7200 * 1e18;
    uint256 public constant initTokenPerBlock = initTokenPerDay / blockPerDay;
    uint256 public constant reduceRatio = 90;
    uint256 public constant maxSupply = 2100e4 * 1e18;

    uint256 public startBlock;
    uint256 public lastRewardBlock;

    uint256 public weight;
    uint256 public accTokenPerWeight;
    uint256 public releasedToken;
    uint256 public harvestedToken;

    mapping(address => uint256) public poolWeight;
    mapping(address => uint256) public poolLastAccTokenPerWeight;
    mapping(address => uint256) public poolStoredToken;
    mapping(address => uint256) public poolHarvestedToken;

    EnumerableSet.AddressSet private pools;

    event AddWeight(address indexed pool, uint256 weight);
    event SubWeight(address indexed pool, uint256 weight);
    event HarvestToken(address indexed pool, uint256 amount);

    /**
     * @param manager Initialize Manager Role
     * @param _startBlock Initialize Start Block
     */
    constructor(address manager, uint256 _startBlock)
        ERC20("Hashland Coin", "HC")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);

        _mint(manager, 210e4 * 1e18);

        startBlock = _startBlock;
    }

    /**
     * @dev Add Weight
     */
    function addWeight(address poolAddr, uint256 _weight)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(block.number >= startBlock, "Block number must >= start block");

        updatePool();

        if (poolWeight[poolAddr] > 0) {
            uint256 pendingToken = (poolWeight[poolAddr] *
                (accTokenPerWeight - poolLastAccTokenPerWeight[poolAddr])) /
                1e18;
            if (pendingToken > 0) {
                poolStoredToken[poolAddr] += pendingToken;
            }
        }

        if (_weight > 0) {
            poolWeight[poolAddr] += _weight;
            weight += _weight;
        }

        poolLastAccTokenPerWeight[poolAddr] = accTokenPerWeight;
        if (poolWeight[poolAddr] > 0) pools.add(poolAddr);

        emit AddWeight(poolAddr, _weight);
    }

    /**
     * @dev Sub Weight
     */
    function subWeight(address poolAddr, uint256 _weight)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(block.number >= startBlock, "Block number must >= start block");
        require(poolWeight[poolAddr] >= _weight, "Not enough weight to sub");

        updatePool();

        uint256 pendingToken = (poolWeight[poolAddr] *
            (accTokenPerWeight - poolLastAccTokenPerWeight[poolAddr])) / 1e18;
        if (pendingToken > 0) {
            poolStoredToken[poolAddr] += pendingToken;
        }

        if (_weight > 0) {
            poolWeight[poolAddr] -= _weight;
            weight -= _weight;
        }

        poolLastAccTokenPerWeight[poolAddr] = accTokenPerWeight;
        if (poolWeight[poolAddr] == 0) pools.remove(poolAddr);

        emit SubWeight(poolAddr, _weight);
    }

    /**
     * @dev Harvest Token
     */
    function harvestToken() external returns (uint256) {
        updatePool();

        uint256 pendingToken = (poolWeight[msg.sender] *
            (accTokenPerWeight - poolLastAccTokenPerWeight[msg.sender])) / 1e18;
        uint256 amount = poolStoredToken[msg.sender] + pendingToken;

        if (amount > 0) {
            poolStoredToken[msg.sender] = 0;
            poolLastAccTokenPerWeight[msg.sender] = accTokenPerWeight;
            poolHarvestedToken[msg.sender] += amount;
            harvestedToken += amount;

            _mint(msg.sender, amount);
        }

        emit HarvestToken(msg.sender, amount);

        return amount;
    }

    /**
     * @dev Get Token Total Rewards of a Pool
     */
    function getTokenTotalRewards(address poolAddr)
        external
        view
        returns (uint256)
    {
        return poolHarvestedToken[poolAddr] + getTokenRewards(poolAddr);
    }

    /**
     * @dev Get Next Reduction Left Blocks
     */
    function getNextReductionLeftBlocks() external view returns (uint256) {
        return
            blockPerQuarter - ((block.number - startBlock) % blockPerQuarter);
    }

    /**
     * @dev Get Pool Token Per Block
     */
    function getPoolTokenPerBlock(address poolAddr)
        external
        view
        returns (uint256)
    {
        return (getTokenPerBlock() * poolWeight[poolAddr]) / weight;
    }

    /**
     * @dev Get Pools Length
     */
    function getPoolsLength() external view returns (uint256) {
        return pools.length();
    }

    /**
     * @dev Get Pools by Size
     */
    function getPoolsBySize(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory, uint256)
    {
        uint256 length = size;
        if (length > pools.length() - cursor) {
            length = pools.length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = pools.at(cursor + i);
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

        if (block.number > lastRewardBlock && weight > 0) {
            uint256 amount = getTokenPerBlock() *
                (block.number - lastRewardBlock);
            accTokenPerWeight += (amount * 1e18) / weight;
            releasedToken += amount;
        }

        lastRewardBlock = block.number;
    }

    /**
     * @dev Get Reduce Count
     */
    function getReduceCount() public view returns (uint256) {
        uint256 count = (block.number - startBlock) / blockPerQuarter;
        return count < 12 ? count : 12;
    }

    /**
     * @dev Get Token Per Block
     */
    function getTokenPerBlock() public view returns (uint256) {
        uint256 amount = (initTokenPerBlock * reduceRatio**getReduceCount()) /
            100**getReduceCount();
        return totalSupply() < maxSupply ? amount : 0;
    }

    /**
     * @dev Get Token Rewards of a Pool
     */
    function getTokenRewards(address poolAddr) public view returns (uint256) {
        uint256 accTokenPerWeightTemp = accTokenPerWeight;
        if (weight > 0) {
            accTokenPerWeightTemp +=
                (getTokenPerBlock() * (block.number - lastRewardBlock) * 1e18) /
                weight;
        }

        return
            poolStoredToken[poolAddr] +
            ((poolWeight[poolAddr] *
                (accTokenPerWeightTemp - poolLastAccTokenPerWeight[poolAddr])) /
                1e18);
    }
}
