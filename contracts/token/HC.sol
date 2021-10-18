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

    uint256 public constant initHCPerDay = 7200 * 1e18;
    uint256 public constant blockPerDay = 28800;
    uint256 public constant blockPerQuarter = (blockPerDay * 365) / 4;
    uint256 public constant initHCPerBlock = initHCPerDay / blockPerDay;
    uint256 public constant reduceRatio = 90;

    uint256 public startBlock;

    mapping(address => uint256) poolWeight;
    mapping(address => uint256) poolLastRewardBlock;

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
     * @dev Add pools
     */
    function addPool(address[] calldata poolAddrs, uint256[] calldata weights)
        external
        onlyRole(MANAGER_ROLE)
    {
        mintAll();

        require(poolAddrs.length == weights.length, "Data length mismatch");

        for (uint256 i = 0; i < poolAddrs.length; i++) {
            pools.add(poolAddrs[i]);
            poolWeight[poolAddrs[i]] = weights[i];
            poolLastRewardBlock[poolAddrs[i]] = block.number;
        }
    }

    /**
     * @dev Remove pools
     */
    function removePool(address[] calldata poolAddrs)
        external
        onlyRole(MANAGER_ROLE)
    {
        mintAll();

        for (uint256 i = 0; i < poolAddrs.length; i++) {
            pools.remove(poolAddrs[i]);
        }
    }

    /**
     * @dev Get Pools Length
     */
    function getUsersLength() external view returns (uint256) {
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
     * @dev Mint HC to a pool
     */
    function mint(address poolAddr) public {
        if (pools.contains(poolAddr)) {
            if (
                poolLastRewardBlock[poolAddr] > 0 &&
                block.number > poolLastRewardBlock[poolAddr]
            ) {
                _mint(poolAddr, getPoolHCReward(poolAddr));
            }

            poolLastRewardBlock[poolAddr] = block.number;
        }
    }

    /**
     * @dev Mint HC to all pools
     */
    function mintAll() public {
        for (uint256 i = 0; i < pools.length(); i++) {
            mint(pools.at(i));
        }
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
        return initHCPerBlock * (reduceRatio / 100)**getReduceCount();
    }

    /**
     * @dev Get Total Weight
     */
    function getTotalWeight() public view returns (uint256) {
        uint256 totalWeight;
        for (uint256 i = 0; i < pools.length(); i++) {
            totalWeight += poolWeight[pools.at(i)];
        }

        return totalWeight;
    }

    /**
     * @dev Get Pool HC Per Block
     */
    function getPoolHCPerBlock(address poolAddr) public view returns (uint256) {
        return (getHCPerBlock() * poolWeight[poolAddr]) / getTotalWeight();
    }

    /**
     * @dev Get Pool HC Reward
     */
    function getPoolHCReward(address poolAddr) public view returns (uint256) {
        return
            getPoolHCPerBlock(poolAddr) *
            (block.number - poolLastRewardBlock[poolAddr]);
    }
}
