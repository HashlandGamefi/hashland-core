// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

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
    mapping(uint256 => uint256) public level;
    mapping(uint256 => uint256) public spawntime;
    mapping(uint256 => uint256) public seed;
    mapping(uint256 => mapping(uint256 => uint256)) public hashrates;
    mapping(uint256 => mapping(string => mapping(uint256 => uint256)))
        public datas;

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
        uint256 _level,
        uint256[] calldata _hashrates
    ) external onlyRole(SPAWNER_ROLE) returns (uint256) {
        uint256 newHnId = totalSupply();

        level[newHnId] = _level;
        for (uint256 i = 0; i < _hashrates.length; i++) {
            hashrates[newHnId][i] = _hashrates[i];
        }
        spawntime[newHnId] = block.timestamp;
        seed[newHnId] = uint256(
            keccak256(
                abi.encodePacked(
                    to,
                    _level,
                    _hashrates,
                    newHnId,
                    block.timestamp
                )
            )
        );

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
     * @dev Set Seed
     */
    function setSeed(uint256 hnId, uint256 _seed)
        external
        onlyRole(SETTER_ROLE)
    {
        seed[hnId] = _seed;
    }

    /**
     * @dev Set Hashrate
     */
    function setHashrate(
        uint256 hnId,
        uint256 index,
        uint256 _hashrate
    ) external onlyRole(SETTER_ROLE) {
        hashrates[hnId][index] = _hashrate;
    }

    /**
     * @dev Rename Hn
     */
    function renameHn(uint256 hnId, string calldata _name) external {
        require(ownerOf(hnId) == msg.sender, "This Hn is not Own");
        name[hnId] = _name;
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
