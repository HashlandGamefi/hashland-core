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
    uint256 public constant initHCPerDay = 7200 * 1e18;
    uint256 public constant initHCPerBlock = initHCPerDay / blockPerDay;
    uint256 public constant reduceRatio = 90;

    uint256 public startBlock;
    uint256 public lastRewardBlock;

    uint256 public weight;
    uint256 public accHCPerWeight;
    uint256 public releasedHC;
    uint256 public harvestedHC;

    mapping(address => uint256) public poolWeight;
    mapping(address => uint256) public poolLastAccHCPerWeight;
    mapping(address => uint256) public poolStoredHC;
    mapping(address => uint256) public poolHarvestedHC;

    EnumerableSet.AddressSet private pools;

    /**
     * @param manager Initialize Manager Role
     * @param _startBlock Initialize Start Block
     */
    constructor(address manager, uint256 _startBlock)
        ERC20("Hashland Coin", "HC")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);

        _mint(manager, 1e6 * 1e18);

        startBlock = _startBlock;
    }

    /**
     * @dev Add Weight
     */
    function addWeight(address poolAddr, uint256 _weight)
        external
        onlyRole(MANAGER_ROLE)
    {
        updatePool();

        if (poolWeight[poolAddr] > 0) {
            uint256 pendingHC = (poolWeight[poolAddr] *
                (accHCPerWeight - poolLastAccHCPerWeight[poolAddr])) / 1e18;
            if (pendingHC > 0) {
                poolStoredHC[poolAddr] += pendingHC;
            }
        }

        if (_weight > 0) {
            poolWeight[poolAddr] += _weight;
            weight += _weight;
        }

        poolLastAccHCPerWeight[poolAddr] = accHCPerWeight;
        if (poolWeight[poolAddr] > 0) pools.add(poolAddr);
    }

    /**
     * @dev Sub Weight
     */
    function subWeight(address poolAddr, uint256 _weight)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(poolWeight[poolAddr] >= _weight, "Not enough weight");

        updatePool();

        uint256 pendingHC = (poolWeight[poolAddr] *
            (accHCPerWeight - poolLastAccHCPerWeight[poolAddr])) / 1e18;
        if (pendingHC > 0) {
            poolStoredHC[poolAddr] += pendingHC;
        }

        if (_weight > 0) {
            poolWeight[poolAddr] -= _weight;
            weight -= _weight;
        }

        poolLastAccHCPerWeight[poolAddr] = accHCPerWeight;
        if (poolWeight[poolAddr] == 0) pools.remove(poolAddr);
    }

    /**
     * @dev Harvest HC
     */
    function harvestHC() external returns (uint256) {
        updatePool();
        uint256 pendingHC = (poolWeight[msg.sender] *
            (accHCPerWeight - poolLastAccHCPerWeight[msg.sender])) / 1e18;
        uint256 amount = poolStoredHC[msg.sender] + pendingHC;

        if (amount > 0) {
            poolStoredHC[msg.sender] = 0;
            poolLastAccHCPerWeight[msg.sender] = accHCPerWeight;
            poolHarvestedHC[msg.sender] += amount;
            harvestedHC += amount;

            _mint(msg.sender, amount);
        }

        return amount;
    }

    /**
     * @dev Get HC Total Rewards of a Pool
     */
    function getHCTotalRewards(address poolAddr)
        external
        view
        returns (uint256)
    {
        return poolHarvestedHC[poolAddr] + getHCRewards(poolAddr);
    }

    /**
     * @dev Get Next Reduction Left Blocks
     */
    function getNextReductionLeftBlocks() external view returns (uint256) {
        return
            blockPerQuarter - ((block.number - startBlock) % blockPerQuarter);
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
            uint256 hcRewards = getHCPerBlock() *
                (block.number - lastRewardBlock);
            accHCPerWeight += (hcRewards * 1e18) / weight;
            releasedHC += hcRewards;
        }

        lastRewardBlock = block.number;
    }

    /**
     * @dev Get Reduce Count
     */
    function getReduceCount() public view returns (uint256) {
        return (block.number - startBlock) / blockPerQuarter;
    }

    /**
     * @dev Get HC Per Block
     */
    function getHCPerBlock() public view returns (uint256) {
        return
            (initHCPerBlock * reduceRatio**getReduceCount()) /
            100**getReduceCount();
    }

    /**
     * @dev Get HC Rewards of a Pool
     */
    function getHCRewards(address poolAddr) public view returns (uint256) {
        uint256 accHCPerWeightTemp = accHCPerWeight;
        if (weight > 0) {
            accHCPerWeightTemp +=
                (getHCPerBlock() * (block.timestamp - lastRewardBlock) * 1e18) /
                weight;
        }

        return
            poolStoredHC[poolAddr] +
            ((poolWeight[poolAddr] *
                (accHCPerWeightTemp - poolLastAccHCPerWeight[poolAddr])) /
                1e18);
    }
}
