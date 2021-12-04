// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Hash Warfare Deposit Contract
 * @author HASHLAND-TEAM
 * @notice In this contract, players can use HC to redeem Diamonds in Hash Warfare
 */
contract HWDeposit is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public hc;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bool public openStatus = false;

    address[] public receivingAddrs;
    uint256[] public weights;
    uint256 public totalWeight;

    uint256 public totalDepositCount;
    uint256 public totalDepositAmount;
    mapping(address => uint256) public userDepositCount;
    mapping(address => uint256) public userDepositAmount;
    EnumerableSet.AddressSet private users;

    event SetOpenStatus(bool status);
    event SetReceivingData(
        address[] receivingAddrs,
        uint256[] weights,
        uint256 totalWeight
    );
    event Deposit(address user, uint256 amount);

    /**
     * @param hcAddr Initialize HC Address
     * @param manager Initialize Manager Role
     */
    constructor(address hcAddr, address manager) {
        hc = IERC20(hcAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;

        emit SetOpenStatus(status);
    }

    /**
     * @dev Set Receiving Data
     */
    function setReceivingData(
        address[] calldata _receivingAddrs,
        uint256[] calldata _weights
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _receivingAddrs.length == _weights.length,
            "Receiving data length mismatch"
        );

        receivingAddrs = _receivingAddrs;
        weights = _weights;

        uint256 _totalWeight;
        for (uint256 i = 0; i < _receivingAddrs.length; i++) {
            _totalWeight += _weights[i];
        }
        totalWeight = _totalWeight;

        emit SetReceivingData(_receivingAddrs, _weights, _totalWeight);
    }

    /**
     * @dev Deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(openStatus, "This feature has not been turned on");

        hc.safeTransferFrom(msg.sender, address(this), amount);

        for (uint256 i = 0; i < receivingAddrs.length; i++) {
            hc.safeTransfer(
                receivingAddrs[i],
                (amount * weights[i]) / totalWeight
            );
        }

        totalDepositCount++;
        totalDepositAmount += amount;
        userDepositCount[msg.sender]++;
        userDepositAmount[msg.sender] += amount;
        users.add(msg.sender);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Get Receiving Data
     */
    function getReceivingData()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256
        )
    {
        return (receivingAddrs, weights, totalWeight);
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
}
