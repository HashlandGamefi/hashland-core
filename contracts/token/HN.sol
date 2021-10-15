// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title Hashland NFT
 * @author HASHLAND-TEAM
 * @notice This Contract Supply HN
 */
contract HN is ERC721Enumerable, AccessControlEnumerable {
    bytes32 public constant SPAWNER_ROLE = keccak256("SPAWNER_ROLE");
    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    mapping(uint256 => string) public name;
    mapping(uint256 => uint256) public ip;
    mapping(uint256 => uint256) public series;
    mapping(uint256 => uint256) public level;
    mapping(uint256 => uint256) public spawntime;
    mapping(uint256 => uint256[]) public hashrates;

    mapping(uint256 => mapping(string => uint256)) public data;
    mapping(uint256 => mapping(string => uint256[])) public datas;

    /**
     * @param spawner Initialize Spawner Role
     * @param setter Initialize Setter Role
     */
    constructor(address spawner, address setter) ERC721("Hashland NFT", "HN") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SPAWNER_ROLE, spawner);
        _setupRole(SETTER_ROLE, setter);
    }

    /**
     * @dev Spawn a New Hn to an Address
     */
    function spawnHn(
        address to,
        uint256 _ip,
        uint256 _series,
        uint256 _level,
        uint256[] calldata _hashrates
    ) external onlyRole(SPAWNER_ROLE) returns (uint256) {
        uint256 newHnId = totalSupply();

        ip[newHnId] = _ip;
        series[newHnId] = _series;
        level[newHnId] = _level;
        hashrates[newHnId] = _hashrates;
        spawntime[newHnId] = block.timestamp;

        _safeMint(to, newHnId);

        return newHnId;
    }

    /**
     * @dev Set Level
     */
    function setLevel(uint256 hnId, uint256 _level)
        external
        onlyRole(SETTER_ROLE)
    {
        level[hnId] = _level;
    }

    /**
     * @dev Set Hashrates
     */
    function setHashrates(uint256 hnId, uint256[] calldata _hashrates)
        external
        onlyRole(SETTER_ROLE)
    {
        hashrates[hnId] = _hashrates;
    }

    /**
     * @dev Set Data
     */
    function setData(
        uint256 hnId,
        string calldata slot,
        uint256 _data
    ) external onlyRole(SETTER_ROLE) {
        data[hnId][slot] = _data;
    }

    /**
     * @dev Set Datas
     */
    function setDatas(
        uint256 hnId,
        string calldata slot,
        uint256[] calldata _datas
    ) external onlyRole(SETTER_ROLE) {
        datas[hnId][slot] = _datas;
    }

    /**
     * @dev Rename Hn
     */
    function renameHn(uint256 hnId, string calldata _name) external {
        require(ownerOf(hnId) == msg.sender, "This Hn is not own");
        name[hnId] = _name;
    }

    /**
     * @dev Transfer Batch
     */
    function transferBatch(address to, uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(msg.sender, to, tokenIds[i]);
        }
    }

    /**
     * @dev Get Hashrates
     */
    function getHashrates(uint256 hnId)
        external
        view
        returns (uint256[] memory)
    {
        return hashrates[hnId];
    }

    /**
     * @dev Get Datas
     */
    function getDatas(uint256 hnId, string calldata slot)
        external
        view
        returns (uint256[] memory)
    {
        return datas[hnId][slot];
    }

    /**
     * @dev Returns a list of token IDs owned by `user` given a `cursor` and `size` of its token list
     */
    function tokensOfOwnerBySize(
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > balanceOf(user) - cursor) {
            length = balanceOf(user) - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = tokenOfOwnerByIndex(user, cursor + i);
        }

        return (values, cursor + length);
    }

    /**
     * @dev Get Random Number
     */
    function getRandomNumber(
        uint256 hnId,
        string calldata slot,
        uint256 base,
        uint256 range
    ) external pure returns (uint256) {
        uint256 randomness = uint256(keccak256(abi.encodePacked(hnId, slot)));
        return base + (randomness % range);
    }

    /**
     * @dev IERC165-supportsInterface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlEnumerable, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
