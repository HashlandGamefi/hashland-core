// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/interface/IHN.sol";
import "../pool/interface/IHNPool.sol";

/**
 * @title HN Market Contract
 * @author HASHLAND-TEAM
 * @notice In this contract users can trade HN
 */
contract HNMarket is ERC721Holder, AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    IHN public hn;
    IHNPool public hnPool;
    IERC20 public hc;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant HNPOOL_ROLE = keccak256("HNPOOL_ROLE");

    bool public openStatus = false;
    address public receivingAddress;
    uint256 public feeRatio = 500;

    uint256 public totalSellAmount;
    uint256 public totalFeeAmount;
    uint256 public totalSellCount;

    mapping(uint256 => uint256) public hnPrice;
    mapping(uint256 => address) public hnSeller;
    mapping(uint256 => bool) public hnIsInPool;

    mapping(address => uint256) public sellerTotalSellAmount;
    mapping(address => uint256) public sellerTotalSellCount;
    mapping(address => uint256) public buyerTotalBuyAmount;
    mapping(address => uint256) public buyerTotalBuyCount;

    EnumerableSet.AddressSet private sellers;
    EnumerableSet.AddressSet private buyers;
    EnumerableSet.UintSet private hnIds;
    mapping(uint256 => EnumerableSet.UintSet) private levelHnIds;
    mapping(address => EnumerableSet.UintSet) private sellerHnIds;
    mapping(address => mapping(uint256 => EnumerableSet.UintSet))
        private sellerLevelHnIds;

    event SetOpenStatus(bool status);
    event SetFeeRatio(uint256 ratio);
    event SetReceivingAddress(address receivingAddr);
    event Sell(
        address indexed seller,
        uint256[] hnIds,
        uint256[] prices,
        bool[] isInPools
    );
    event Cancel(address indexed seller, uint256[] hnIds, bool isHnPoolCancel);
    event Buy(
        address indexed buyer,
        address[] sellers,
        uint256[] hnIds,
        uint256[] prices,
        bool[] isInPools
    );

    /**
     * @param hnAddr Initialize HN Address
     * @param hnPoolAddr Initialize HNPool Address
     * @param hcAddr Initialize HC Address
     * @param receivingAddr Initialize Receiving Address
     * @param manager Initialize Manager Role
     */
    constructor(
        address hnAddr,
        address hnPoolAddr,
        address hcAddr,
        address receivingAddr,
        address manager
    ) {
        hn = IHN(hnAddr);
        hnPool = IHNPool(hnPoolAddr);
        hc = IERC20(hcAddr);

        receivingAddress = receivingAddr;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, manager);
        _setupRole(HNPOOL_ROLE, hnPoolAddr);
    }

    /**
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;

        emit SetOpenStatus(status);
    }

    /**
     * @dev Set Fee Ratio
     */
    function setFeeRatio(uint256 ratio) external onlyRole(MANAGER_ROLE) {
        require(ratio <= 2000, "The fee ratio cannot exceed 20%");
        feeRatio = ratio;

        emit SetFeeRatio(ratio);
    }

    /**
     * @dev Set Receiving Address
     */
    function setReceivingAddress(address receivingAddr)
        external
        onlyRole(MANAGER_ROLE)
    {
        receivingAddress = receivingAddr;

        emit SetReceivingAddress(receivingAddr);
    }

    /**
     * @dev HN Pool Cancel
     */
    function hnPoolCancel(address seller, uint256[] calldata _hnIds)
        external
        onlyRole(HNPOOL_ROLE)
    {
        for (uint256 i = 0; i < _hnIds.length; i++) {
            if (
                hnIds.contains(_hnIds[i]) &&
                sellerHnIds[seller].contains(_hnIds[i])
            ) {
                uint256 level = hn.level(_hnIds[i]);
                hnIds.remove(_hnIds[i]);
                levelHnIds[level].remove(_hnIds[i]);
                sellerHnIds[seller].remove(_hnIds[i]);
                sellerLevelHnIds[seller][level].remove(_hnIds[i]);
            }
            if (i == _hnIds.length - 1) emit Cancel(seller, _hnIds, true);
        }
    }

    /**
     * @dev Sell
     */
    function sell(
        uint256[] calldata _hnIds,
        uint256[] calldata prices,
        bool[] calldata isInPools
    ) external nonReentrant {
        require(
            _hnIds.length == prices.length && _hnIds.length == isInPools.length,
            "Data length mismatch"
        );
        require(openStatus, "This pool is not opened");

        for (uint256 i = 0; i < _hnIds.length; i++) {
            if (isInPools[i]) {
                require(
                    hnPool.getUserHnIdExistence(msg.sender, _hnIds[i]),
                    "This HN is not own"
                );
            } else {
                hn.safeTransferFrom(msg.sender, address(this), _hnIds[i]);
            }

            uint256 level = hn.level(_hnIds[i]);
            hnIds.add(_hnIds[i]);
            levelHnIds[level].add(_hnIds[i]);
            sellerHnIds[msg.sender].add(_hnIds[i]);
            sellerLevelHnIds[msg.sender][level].add(_hnIds[i]);

            hnPrice[_hnIds[i]] = prices[i];
            hnSeller[_hnIds[i]] = msg.sender;
            hnIsInPool[_hnIds[i]] = isInPools[i];
        }

        emit Sell(msg.sender, _hnIds, prices, isInPools);
    }

    /**
     * @dev Cancel
     */
    function cancel(uint256[] calldata _hnIds) external nonReentrant {
        for (uint256 i = 0; i < _hnIds.length; i++) {
            require(hnIds.contains(_hnIds[i]), "This HN does not exist");
            require(
                sellerHnIds[msg.sender].contains(_hnIds[i]),
                "This HN is not own"
            );

            uint256 level = hn.level(_hnIds[i]);
            hnIds.remove(_hnIds[i]);
            levelHnIds[level].remove(_hnIds[i]);
            sellerHnIds[msg.sender].remove(_hnIds[i]);
            sellerLevelHnIds[msg.sender][level].remove(_hnIds[i]);

            if (!hnIsInPool[_hnIds[i]])
                hn.safeTransferFrom(address(this), msg.sender, _hnIds[i]);
        }

        emit Cancel(msg.sender, _hnIds, false);
    }

    /**
     * @dev Buy
     */
    function buy(uint256[] calldata _hnIds) external nonReentrant {
        address[] memory _sellers = new address[](_hnIds.length);
        uint256[] memory prices = new uint256[](_hnIds.length);
        bool[] memory isInPools = new bool[](_hnIds.length);

        for (uint256 i = 0; i < _hnIds.length; i++) {
            require(hnIds.contains(_hnIds[i]), "This HN does not exist");
            prices[i] = hnPrice[_hnIds[i]];
            uint256 feeAmount = (prices[i] * feeRatio) / 1e4;
            uint256 sellAmount = prices[i] - feeAmount;

            _sellers[i] = hnSeller[_hnIds[i]];
            isInPools[i] = hnIsInPool[_hnIds[i]];

            uint256 level = hn.level(_hnIds[i]);
            hnIds.remove(_hnIds[i]);
            levelHnIds[level].remove(_hnIds[i]);
            sellerHnIds[_sellers[i]].remove(_hnIds[i]);
            sellerLevelHnIds[_sellers[i]][level].remove(_hnIds[i]);

            hc.safeTransferFrom(msg.sender, _sellers[i], sellAmount);
            hc.safeTransferFrom(msg.sender, receivingAddress, feeAmount);
            if (isInPools[i]) {
                hnPool.hnMarketWithdraw(msg.sender, _sellers[i], _hnIds[i]);
            } else {
                hn.safeTransferFrom(address(this), msg.sender, _hnIds[i]);
            }

            sellerTotalSellAmount[_sellers[i]] += sellAmount;
            sellerTotalSellCount[_sellers[i]]++;
            sellers.add(_sellers[i]);

            buyerTotalBuyAmount[msg.sender] += prices[i];
            buyerTotalBuyCount[msg.sender]++;

            totalSellAmount += sellAmount;
            totalFeeAmount += feeAmount;
            totalSellCount++;
        }
        buyers.add(msg.sender);

        emit Buy(msg.sender, _sellers, _hnIds, prices, isInPools);
    }

    /**
     * @dev Get Sellers Length
     */
    function getSellersLength() external view returns (uint256) {
        return sellers.length();
    }

    /**
     * @dev Get Sellers by Size
     */
    function getSellersBySize(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory, uint256)
    {
        uint256 length = size;
        if (length > sellers.length() - cursor) {
            length = sellers.length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = sellers.at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Buyers Length
     */
    function getBuyersLength() external view returns (uint256) {
        return buyers.length();
    }

    /**
     * @dev Get Buyers by Size
     */
    function getBuyersBySize(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory, uint256)
    {
        uint256 length = size;
        if (length > buyers.length() - cursor) {
            length = buyers.length() - cursor;
        }

        address[] memory values = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = buyers.at(cursor + i);
        }

        return (values, cursor + length);
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
     * @dev Get Each Level HnIds Length
     */
    function getEachLevelHnIdsLength(uint256 maxLevel)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory lengths = new uint256[](maxLevel);
        for (uint256 i = 0; i < maxLevel; i++) {
            lengths[i] = levelHnIds[i + 1].length();
        }
        return lengths;
    }

    /**
     * @dev Get Level HnIds Length
     */
    function getLevelHnIdsLength(uint256 level)
        external
        view
        returns (uint256)
    {
        return levelHnIds[level].length();
    }

    /**
     * @dev Get Level HnIds by Size
     */
    function getLevelHnIdsBySize(
        uint256 level,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > levelHnIds[level].length() - cursor) {
            length = levelHnIds[level].length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = levelHnIds[level].at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Seller HnId Existence
     */
    function getSellerHnIdExistence(address seller, uint256 hnId)
        external
        view
        returns (bool)
    {
        return sellerHnIds[seller].contains(hnId);
    }

    /**
     * @dev Get Seller HnIds Length
     */
    function getSellerHnIdsLength(address seller)
        external
        view
        returns (uint256)
    {
        return sellerHnIds[seller].length();
    }

    /**
     * @dev Get Seller HnIds by Size
     */
    function getSellerHnIdsBySize(
        address seller,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > sellerHnIds[seller].length() - cursor) {
            length = sellerHnIds[seller].length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = sellerHnIds[seller].at(cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Seller Each Level HnIds Length
     */
    function getSellerEachLevelHnIdsLength(address seller, uint256 maxLevel)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory lengths = new uint256[](maxLevel);
        for (uint256 i = 0; i < maxLevel; i++) {
            lengths[i] = sellerLevelHnIds[seller][i + 1].length();
        }
        return lengths;
    }

    /**
     * @dev Get Seller Level HnIds Length
     */
    function getSellerLevelHnIdsLength(address seller, uint256 level)
        external
        view
        returns (uint256)
    {
        return sellerLevelHnIds[seller][level].length();
    }

    /**
     * @dev Get Seller Level HnIds by Size
     */
    function getSellerLevelHnIdsBySize(
        address seller,
        uint256 level,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > sellerLevelHnIds[seller][level].length() - cursor) {
            length = sellerLevelHnIds[seller][level].length() - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = sellerLevelHnIds[seller][level].at(cursor + i);
        }

        return (values, cursor + length);
    }
}
