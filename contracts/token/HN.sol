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

    struct Hn {
        string name;
        uint256 ip;
        uint256 level;
        uint256 race;
        uint256 class;
        uint256[] attributes;
        uint256[] spells;
        uint256[] items;
        uint256[] metadatas;
        uint256 spawnTime;
        uint256 seed;
    }

    Hn[] public hns;

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
        string calldata name,
        uint256 ip,
        uint256 level,
        uint256 race,
        uint256 class,
        uint256[] calldata attributes,
        uint256[] calldata spells,
        uint256[] calldata items,
        uint256[] calldata metadatas
    ) external onlyRole(SPAWNER_ROLE) returns (uint256) {
        uint256 newHnId = hns.length;

        hns.push(
            Hn(
                name,
                ip,
                level,
                race,
                class,
                attributes,
                spells,
                items,
                metadatas,
                block.timestamp,
                uint256(
                    keccak256(
                        abi.encodePacked(
                            newHnId,
                            to,
                            name,
                            ip,
                            level,
                            race,
                            class,
                            attributes,
                            spells,
                            items,
                            metadatas,
                            block.timestamp
                        )
                    )
                )
            )
        );

        _safeMint(to, newHnId);

        return newHnId;
    }

    /**
     * @dev Set Metadata
     */
    function setMetadata(uint256 hnId, uint256[] calldata metadatas)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.metadatas = metadatas;
    }

    /**
     * @dev Set Metadata By Index
     */
    function setMetadataByIndex(
        uint256 hnId,
        uint256 metadata,
        uint256 index
    ) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.metadatas[index] = metadata;
    }

    /**
     * @dev Rename Hn
     */
    function renameHn(uint256 hnId, string calldata name) external {
        require(ownerOf(hnId) == msg.sender, "This Hn is not Own");
        Hn storage hn = hns[hnId];
        hn.name = name;
    }

    /**
     * @dev Get Hn Metadatas
     */
    function getHnMetadatas(uint256 hnId)
        external
        view
        returns (uint256[] memory)
    {
        Hn memory hn = hns[hnId];
        return hn.metadatas;
    }

    /**
     * @dev Get Hn Metadata By Index
     */
    function getHnMetadataByIndex(uint256 hnId, uint256 index)
        external
        view
        returns (uint256)
    {
        Hn memory hn = hns[hnId];
        return hn.metadatas[index];
    }

    /**
     * @dev Get Hn Race
     */
    function getHnRace(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.race;
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
