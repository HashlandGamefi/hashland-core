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
        uint256[] hashrates;
        uint256[] attributes;
        uint256[] spells;
        uint256[] items;
        uint256[] metadatas;
        uint256 spawntime;
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
        uint256[] calldata hashrates,
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
                hashrates,
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
                            hashrates,
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
     * @dev Set Ip
     */
    function setIp(uint256 hnId, uint256 ip) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.ip = ip;
    }

    /**
     * @dev Set Level
     */
    function setLevel(uint256 hnId, uint256 level)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.level = level;
    }

    /**
     * @dev Set Race
     */
    function setRace(uint256 hnId, uint256 race)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.race = race;
    }

    /**
     * @dev Set Class
     */
    function setClass(uint256 hnId, uint256 class)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.class = class;
    }

    /**
     * @dev Set Hashrates
     */
    function setHashrates(uint256 hnId, uint256[] calldata hashrates)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.hashrates = hashrates;
    }

    /**
     * @dev Set Hashrate By Index
     */
    function setHashrateByIndex(
        uint256 hnId,
        uint256 hashrate,
        uint256 index
    ) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.hashrates[index] = hashrate;
    }

    /**
     * @dev Set Attributes
     */
    function setAttributes(uint256 hnId, uint256[] calldata attributes)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.attributes = attributes;
    }

    /**
     * @dev Set Atrribute By Index
     */
    function setAtrributeByIndex(
        uint256 hnId,
        uint256 attribute,
        uint256 index
    ) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.attributes[index] = attribute;
    }

    /**
     * @dev Set Spells
     */
    function setSpells(uint256 hnId, uint256[] calldata spells)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.spells = spells;
    }

    /**
     * @dev Set Spell By Index
     */
    function setSpellByIndex(
        uint256 hnId,
        uint256 spell,
        uint256 index
    ) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.spells[index] = spell;
    }

    /**
     * @dev Set Items
     */
    function setItems(uint256 hnId, uint256[] calldata items)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.items = items;
    }

    /**
     * @dev Set Item By Index
     */
    function setItemByIndex(
        uint256 hnId,
        uint256 item,
        uint256 index
    ) external onlyRole(SETTER_ROLE) {
        Hn storage hn = hns[hnId];
        hn.items[index] = item;
    }

    /**
     * @dev Set Metadatas
     */
    function setMetadatas(uint256 hnId, uint256[] calldata metadatas)
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
     * @dev Set Seed
     */
    function setSeed(uint256 hnId, uint256 seed)
        external
        onlyRole(SETTER_ROLE)
    {
        Hn storage hn = hns[hnId];
        hn.seed = seed;
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
     * @dev Get Hn Name
     */
    function getHnName(uint256 hnId) external view returns (string memory) {
        Hn memory hn = hns[hnId];
        return hn.name;
    }

    /**
     * @dev Get Hn Ip
     */
    function getHnIp(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.ip;
    }

    /**
     * @dev Get Hn Level
     */
    function getHnLevel(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.level;
    }

    /**
     * @dev Get Hn Race
     */
    function getHnRace(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.race;
    }

    /**
     * @dev Get Hn Class
     */
    function getHnClass(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.class;
    }

    /**
     * @dev Get Hn Hashrates
     */
    function getHnHashrates(uint256 hnId)
        external
        view
        returns (uint256[] memory)
    {
        Hn memory hn = hns[hnId];
        return hn.hashrates;
    }

    /**
     * @dev Get Hn Hashrate By Index
     */
    function getHnHashrateByIndex(uint256 hnId, uint256 index)
        external
        view
        returns (uint256)
    {
        Hn memory hn = hns[hnId];
        return hn.hashrates[index];
    }

    /**
     * @dev Get Hn Attributes
     */
    function getHnAttributes(uint256 hnId)
        external
        view
        returns (uint256[] memory)
    {
        Hn memory hn = hns[hnId];
        return hn.attributes;
    }

    /**
     * @dev Get Hn Attribute By Index
     */
    function getHnAttributeByIndex(uint256 hnId, uint256 index)
        external
        view
        returns (uint256)
    {
        Hn memory hn = hns[hnId];
        return hn.attributes[index];
    }

    /**
     * @dev Get Hn Spells
     */
    function getHnSpells(uint256 hnId)
        external
        view
        returns (uint256[] memory)
    {
        Hn memory hn = hns[hnId];
        return hn.spells;
    }

    /**
     * @dev Get Hn Spell By Index
     */
    function getHnSpellByIndex(uint256 hnId, uint256 index)
        external
        view
        returns (uint256)
    {
        Hn memory hn = hns[hnId];
        return hn.spells[index];
    }

    /**
     * @dev Get Hn Items
     */
    function getHnItems(uint256 hnId) external view returns (uint256[] memory) {
        Hn memory hn = hns[hnId];
        return hn.items;
    }

    /**
     * @dev Get Hn Item By Index
     */
    function getHnItemByIndex(uint256 hnId, uint256 index)
        external
        view
        returns (uint256)
    {
        Hn memory hn = hns[hnId];
        return hn.items[index];
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
     * @dev Get Hn Spawntime
     */
    function getHnSpawntime(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.spawntime;
    }

    /**
     * @dev Get Hn Seed
     */
    function getHnSeed(uint256 hnId) external view returns (uint256) {
        Hn memory hn = hns[hnId];
        return hn.seed;
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
