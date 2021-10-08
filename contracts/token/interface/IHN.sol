// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @title HN Interface
 * @author HASHLAND-TEAM
 * @notice Interface of the HN
 */
abstract contract IHN is IERC721Enumerable {
    mapping(uint256 => string) public name;
    mapping(uint256 => uint256) public ip;
    mapping(uint256 => uint256) public level;
    mapping(uint256 => uint256) public spawntime;
    mapping(uint256 => uint256) public seed;
    mapping(uint256 => uint256[]) public hashrates;

    mapping(uint256 => mapping(string => uint256)) public data;
    mapping(uint256 => mapping(string => uint256[])) public datas;

    function spawnHn(
        address to,
        uint256 _ip,
        uint256 _level,
        uint256[] calldata _hashrates
    ) external virtual returns (uint256);

    function setLevel(uint256 hnId, uint256 _level) external virtual;

    function setSeed(uint256 hnId, uint256 _seed) external virtual;

    function setHashrates(uint256 hnId, uint256[] calldata _hashrates)
        external
        virtual;

    function setData(
        uint256 hnId,
        string calldata slot,
        uint256 _data
    ) external virtual;

    function setDatas(
        uint256 hnId,
        string calldata slot,
        uint256[] calldata _datas
    ) external virtual;

    function renameHn(uint256 hnId, string calldata _name) external virtual;

    function getHashrates(uint256 hnId)
        external
        view
        virtual
        returns (uint256[] memory);

    function getDatas(uint256 hnId, string calldata slot)
        external
        view
        virtual
        returns (uint256[] memory);

    function getRandomNumber(
        uint256 hnId,
        string calldata slot,
        uint256 base,
        uint256 range
    ) external pure virtual returns (uint256);
}
