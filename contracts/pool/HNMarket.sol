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
    bytes32 public constant HNPOOL_ROLE = keccak256("HNPOOL_ROLE");

    bool public openStatus = false;

    mapping(uint256 => uint256) public hnPrice;
    mapping(uint256 => address) public hnSeller;
    mapping(uint256 => bool) public hnIsInPool;

    mapping(address => uint256) public sellerTotolSellAmount;
    mapping(address => uint256) public sellerTotolSellCount;
    mapping(address => uint256) public buyerTotolBuyAmount;
    mapping(address => uint256) public buyerTotolBuyCount;

    EnumerableSet.AddressSet private sellers;
    EnumerableSet.AddressSet private buyers;
    EnumerableSet.UintSet private hnIds;
    mapping(address => EnumerableSet.UintSet) private sellerHnIds;

    event Sell(address indexed seller, uint256 indexed hnId, uint256 price);
    event Cancel(address indexed seller, uint256 indexed hnId, bool isInPool);
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
        _setupRole(HNPOOL_ROLE, hnPoolAddr);
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
     * @dev Set Open Status
     */
    function setOpenStatus(bool status) external onlyRole(MANAGER_ROLE) {
        openStatus = status;
    }

    /**
     * @dev HN Pool Cancel
     */
    function hnPoolCancel(address seller, uint256 hnId)
        external
        onlyRole(HNPOOL_ROLE)
    {
        if (hnIds.contains(hnId) && sellerHnIds[seller].contains(hnId)) {
            hnIds.remove(hnId);
            sellerHnIds[seller].remove(hnId);

            emit Cancel(seller, hnId, true);
        }
    }

    /**
     * @dev Sell
     */
    function sell(
        uint256 hnId,
        uint256 price,
        bool isInPool
    ) external {
        require(openStatus, "This pool is not opened");

        if (isInPool) {
            require(
                hnPool.getUserHnIdExistence(msg.sender, hnId),
                "This HN is not own"
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
        require(hnIds.contains(hnId), "This HN does not exist");
        require(sellerHnIds[msg.sender].contains(hnId), "This HN is not own");

        hnIds.remove(hnId);
        sellerHnIds[msg.sender].remove(hnId);

        if (!hnIsInPool[hnId])
            hn.safeTransferFrom(address(this), msg.sender, hnId);

        emit Cancel(msg.sender, hnId, false);
    }

    /**
     * @dev Buy
     */
    function buy(uint256 hnId) external payable {
        require(hnIds.contains(hnId), "This HN does not exist");
        uint256 price = hnPrice[hnId];
        require(msg.value == hnPrice[hnId], "Price mismatch");

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
        sellerTotolSellAmount[seller] += price;
        sellerTotolSellCount[seller]++;
        buyerTotolBuyAmount[msg.sender] += price;
        buyerTotolBuyCount[msg.sender]++;

        emit Buy(msg.sender, seller, hnId, price);
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
}
