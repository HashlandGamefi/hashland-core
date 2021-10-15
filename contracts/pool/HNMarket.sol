// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../token/interface/IHN.sol";
import "../pool/interface/IHNPool.sol";

/**
 * @title HN Market Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can trade HN
 */
contract HNMarket is ERC721Holder, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;
    IHNPool public hnPool;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bool public openStatus = false;

    mapping(uint256 => uint256) public hnPrice;
    mapping(uint256 => address) public hnSeller;
    mapping(uint256 => bool) public hnIsInPool;

    EnumerableSet.AddressSet private sellers;
    EnumerableSet.AddressSet private buyers;
    EnumerableSet.UintSet private hnIds;
    mapping(address => EnumerableSet.UintSet) private sellerHnIds;

    event Sell(address indexed seller, uint256 indexed hnId, uint256 price);
    event Cancel(address indexed seller, uint256 indexed hnId);
    event Buy(
        address indexed buyer,
        address indexed seller,
        uint256 indexed hnId,
        uint256 price
    );

    /**
     * @param hnAddr Initialize HN Address
     * @param hnPoolAddr Initialize HNPool Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address hnPoolAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        hnPool = IHNPool(hnPoolAddr);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;
    }

    /**
     * @dev Sell
     */
    function sell(
        uint256 hnId,
        uint256 price,
        bool isInPool
    ) external {
        require(openStatus, "This Pool is not Opened");

        if (isInPool) {
            require(
                hnPool.getUserHnIdExistence(msg.sender, hnId),
                "This HN is not Own"
            );
        } else {
            hn.safeTransferFrom(msg.sender, address(this), hnId);
        }

        hnIds.add(hnId);
        sellerHnIds[msg.sender].add(hnId);
        hnPrice[hnId] = price;
        hnSeller[hnId] = msg.sender;
        hnIsInPool[hnId] = isInPool;

        sellers.add(msg.sender);

        emit Sell(msg.sender, hnId, price);
    }

    /**
     * @dev Cancel
     */
    function cancel(uint256 hnId) external {
        require(hnIds.contains(hnId), "This HN does Not Exist");
        require(sellerHnIds[msg.sender].contains(hnId), "This HN is not Own");

        hnIds.remove(hnId);
        sellerHnIds[msg.sender].remove(hnId);

        if (!hnIsInPool[hnId]) hn.safeTransferFrom(address(this), msg.sender, hnId);

        emit Cancel(msg.sender, hnId);
    }

    /**
     * @dev Buy
     */
    function buy(uint256 hnId) external payable {
        require(hnIds.contains(hnId), "This HN does Not Exist");
        uint256 price = msg.value;
        require(price == hnPrice[hnId], "Wrong price");

        address seller = hnSeller[hnId];
        bool isInPool = hnIsInPool[hnId];

        hnIds.remove(hnId);
        sellerHnIds[seller].remove(hnId);

        payable(seller).transfer(price);
        if (isInPool) {
            hn.safeTransferFrom(address(hnPool), msg.sender, hnId);
        } else {
            hn.safeTransferFrom(address(this), msg.sender, hnId);
        }

        buyers.add(msg.sender);

        emit Buy(msg.sender, seller, hnId, price);
    }
}
