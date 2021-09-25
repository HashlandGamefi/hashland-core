//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MiningNFT is ERC721, Ownable, IERC721Receiver 
{
	uint256 public autoTokenId;
	mapping(uint256=>uint8) public tokenLevel;

	uint256 constant UPGRADE_MATERIAL_NUM = 4;

	event UPGRADE(uint256, uint8, uint8);

    constructor() ERC721("HASH LAND NFT", "HLN") 
    {
    	autoTokenId = 0;
    }

    function _autoIncTokenId() internal returns(uint256)
    {
    	autoTokenId = autoTokenId + 1;
    	return autoTokenId;
    }

    function _setTokenLevel(uint256 tokenId, uint8 level) internal 
    {
    	require(_exists(tokenId), "EEXIST");
    	require(tokenLevel[tokenId] != level, "ESAME");

    	emit UPGRADE(tokenId, tokenLevel[tokenId], level);
    	tokenLevel[tokenId] = level;
    }

    function _mintWithLevel(address to, uint8 level) internal returns(uint256)
    {
    	uint256 tokenId = _autoIncTokenId();
    	require(!_exists(tokenId), "EEXIST");

    	_mint(to, tokenId);
    	_setTokenLevel(tokenId, level);

    	return tokenId;
    }

    function mint(address to, uint8 level) public onlyOwner returns(uint256)
    {
    	return _mintWithLevel(to, level);
    }

    function upgrade(uint256[] calldata material) public returns(uint256)
    {
    	require(material.length == UPGRADE_MATERIAL_NUM, "ENUM");
    	uint8 lvl = tokenLevel[material[0]];

    	for(uint i = 0; i < UPGRADE_MATERIAL_NUM; i ++)
    	{
    		require(_exists(material[i]), "EEXIST");
    		require(lvl == tokenLevel[material[i]], "ELEVEL");
    		safeTransferFrom(msg.sender, address(this), material[i]);
    		_burn(material[i]);
    	}

    	require(lvl + 1 > lvl, "EOVERFLOW");
    	return _mintWithLevel(msg.sender, lvl + 1);
    }

	function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4)
	{
		return this.onERC721Received.selector;
	}
} 