// //SPDX-License-Identifier: MIT

// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol"; 
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/math/Math.sol";
// import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "hardhat/console.sol";
// import "./MiningNFT.sol";

// contract StakingPool is IERC721Receiver, Ownable, ReentrancyGuard
// {
// 	using SafeMath for uint;
// 	using SafeMath for uint256;
// 	using SignedSafeMath for int256;

// 	address public nftAsset;
// 	address public slotAsset;

// 	struct Staker
// 	{
// 		uint8 numSlots;
// 		uint8 numAvailableSlots;
// 		uint256 power;
// 		int256 rewardDebt;
// 		uint256 [] stakedAssets;
// 	}

// 	struct Reward
// 	{
// 		uint256 rewardBalance;
// 		uint256 expiredBlock;
// 		uint256 startBlock;
// 		uint256 totalBalance;
// 		uint256 accRewardPerPower;
// 		uint256 lastRewardBlock;
// 	}

// 	uint8 private constant DEFAULT_SLOTS = 2;
// 	uint8 private constant MAX_SLOTS = 4;
// 	uint256 private constant ACC_REWARD_PRECISION = 1e12;

// 	mapping(address=>Staker) 	public users;
// 	mapping(uint8=>uint256) 		public powerAlloc;
// 	mapping(address=>Reward) 	public rewards;

// 	address[] public rewardList;

// 	uint256 public totalPower;

// 	constructor(address nftAddress, address slotAddress)
// 	{
// 		nftAsset = nftAddress;
// 		slotAsset = slotAddress;
// 		powerAlloc[0] = 0;
// 		powerAlloc[1] = 100;
// 		powerAlloc[2] = 450;
// 		powerAlloc[3] = 2000;
// 		powerAlloc[4] = 10000;
// 		powerAlloc[5] = 50000;
// 	}

// 	function _nftToPower(uint256 tokenId) internal view returns(uint256)
// 	{
// 		uint8 level = MiningNFT(nftAsset).tokenLevel(tokenId);
// 		require(level > 0 && level < 6, "ELEVEL");
// 		return powerAlloc[level];
// 	}

// 	function rewardPerBlock(address token) public view returns(uint256)
// 	{
// 		Reward memory reward = rewards[token];
// 		if(reward.expiredBlock == reward.startBlock)
// 		{
// 			return 0;
// 		}
// 		return reward.rewardBalance.div(reward.expiredBlock.sub(reward.startBlock));
// 	}

// 	function _updateReward(address token) internal
// 	{
// 		Reward memory reward = rewards[token];
// 		uint256 startBlock = Math.max(reward.lastRewardBlock, reward.startBlock);
// 		uint256 endBlock = Math.min(reward.expiredBlock, block.number);

// 		if(endBlock > startBlock)
// 		{
// 			if(totalPower > 0)
// 			{
// 				uint256 blocks = endBlock.sub(startBlock);
// 				uint256 profit = blocks.mul(rewardPerBlock(token));
// 				reward.accRewardPerPower = reward.accRewardPerPower.add(profit.mul(ACC_REWARD_PRECISION) / totalPower);
// 			}
// 			reward.lastRewardBlock = endBlock;
// 			rewards[token] = reward;
// 		}
// 	}

// 	function _updateRewards() internal
// 	{
// 		for(uint i = 0; i < rewardList.length; i ++)
// 		{
// 			_updateReward(rewardList[i]);
// 		}
// 	}

// 	function _updateUserDebt(address user, uint256 power, bool addOrSub) internal
// 	{
// 		for(uint i = 0; i < rewardList.length; i ++)
// 		{
// 			if(addOrSub)
// 			{
// 				users[user].rewardDebt = users[user].rewardDebt.add(
// 					int256(power.mul(rewards[rewardList[i]].accRewardPerPower) / ACC_REWARD_PRECISION)
// 				);
// 			}
// 			else
// 			{
// 				users[user].rewardDebt = users[user].rewardDebt.sub(
// 					int256(power.mul(rewards[rewardList[i]].accRewardPerPower) / ACC_REWARD_PRECISION)
// 				);
// 			}
// 		}	
// 	}

// 	function _arrayRemove(address user, uint256 tokenId) internal
// 	{
// 		for(uint i = 0; i < users[user].stakedAssets.length; i ++)
// 		{
// 			if(tokenId == users[user].stakedAssets[i])
// 			{
// 				users[user].stakedAssets[i]	= users[user].stakedAssets[users[user].stakedAssets.length - 1];
// 				users[user].stakedAssets.pop();
// 				return;
// 			}
// 		}
// 		require(false, "ENOTEXIST");
// 	}

// 	function _checkSlots(address user) internal
// 	{
// 		if(users[user].numSlots == 0)
// 		{
// 			users[user].numSlots = DEFAULT_SLOTS;
// 			users[user].numAvailableSlots = DEFAULT_SLOTS;
// 		}

// 		console.log("user has %s slots, and %s used slots, and %s availableSlots." 
// 			// , user 
// 			, uint256(users[user].numSlots)
// 			, uint256(users[user].stakedAssets.length)
// 			, uint256(users[user].numAvailableSlots)
// 		);
// 		require(users[user].numAvailableSlots + users[user].stakedAssets.length == users[user].numSlots, "ESLOT");
// 		require(users[user].numSlots <= MAX_SLOTS, "EMAXSLOT");
// 	}

// 	function pendingReward(address token, address _user) external view returns (uint256 pending) 
// 	{
// 		Reward memory reward = rewards[token];
// 		Staker memory user   = users[_user];

// 		uint256 accRewardPerPower = reward.accRewardPerPower;
// 		uint256 startBlock = Math.max(reward.lastRewardBlock, reward.startBlock);
// 		uint256 endBlock = Math.min(reward.expiredBlock, block.number);

// 		if (endBlock > startBlock && totalPower != 0) {
// 			uint256 blocks = endBlock.sub(startBlock);
// 			uint256 tokenReward = blocks.mul(rewardPerBlock(token));
// 			accRewardPerPower = accRewardPerPower.add(tokenReward.mul(ACC_REWARD_PRECISION) / totalPower);
// 		}
// 		pending = uint256(int256(user.power.mul(accRewardPerPower) / ACC_REWARD_PRECISION).sub(user.rewardDebt));
// 	}

// 	function addReward(address token, uint256 amount, uint256 numBlocks) public onlyOwner
// 	{
// 		require(numBlocks > 0, "EBLOCK");
// 		require(amount > 0, "EAMOUNT");

// 		_updateReward(token);
// 		IERC20(token).transferFrom(msg.sender, address(this), amount);

// 		Reward memory reward = rewards[token];
// 		if(reward.expiredBlock == 0)
// 		{
// 			rewardList.push(token);
// 		}

// 		if(reward.expiredBlock > block.number)
// 		{
// 			reward.rewardBalance = reward.rewardBalance.mul(reward.expiredBlock.sub(block.number))
// 				.div(reward.expiredBlock.sub(reward.startBlock));				
// 		}

// 		reward.rewardBalance = reward.rewardBalance.add(amount);
// 		reward.startBlock = block.number;
// 		reward.expiredBlock = block.number.add(numBlocks);
// 		reward.totalBalance = reward.totalBalance.add(amount);
// 		rewards[token] = reward;
// 	}

// 	function increaseSlot(uint256 slotTokenId) public nonReentrant
// 	{
// 		require(IERC721(slotAsset).ownerOf(slotTokenId) == msg.sender, "ENOTEXIST");
// 		IERC721(slotAsset).safeTransferFrom(msg.sender, address(this), slotTokenId);

// 		_checkSlots(msg.sender);
// 		users[msg.sender].numSlots += 1;
// 		users[msg.sender].numAvailableSlots += 1;
// 		_checkSlots(msg.sender);
// 	}

// 	function deposit(uint256[] calldata stakingNFTs) public nonReentrant
// 	{
// 		_checkSlots(msg.sender);

// 		require(stakingNFTs.length > 0, "EARRAY");
// 		require(users[msg.sender].numAvailableSlots >= stakingNFTs.length, "ESLOT");

// 		users[msg.sender].numAvailableSlots -= uint8(stakingNFTs.length);

// 		_updateRewards();

// 		uint256 accPower = 0;
// 		for(uint i = 0; i < stakingNFTs.length; i ++)
// 		{
// 			uint256 tokenId = stakingNFTs[i];
// 			accPower = accPower.add(_nftToPower(tokenId));
// 			users[msg.sender].stakedAssets.push(tokenId);
// 			IERC721(nftAsset).safeTransferFrom(msg.sender, address(this), tokenId);
// 		}

// 		_checkSlots(msg.sender);

// 		users[msg.sender].power = users[msg.sender].power.add(accPower);
// 		totalPower = totalPower.add(accPower);

// 		_updateUserDebt(msg.sender, accPower, true);
// 	}

// 	function withdraw(uint256[] calldata stakingNFTs) public nonReentrant
// 	{
// 		require(stakingNFTs.length > 0, "EARRAY");
// 		require(users[msg.sender].numSlots - users[msg.sender].numAvailableSlots >= uint8(stakingNFTs.length), "ESLOT");

// 		users[msg.sender].numAvailableSlots += uint8(stakingNFTs.length);

// 		_updateRewards();

// 		uint256 accPower = 0;
// 		for(uint i = 0; i < stakingNFTs.length; i ++)
// 		{
// 			uint256 tokenId = stakingNFTs[i];
// 			accPower = accPower.add(_nftToPower(tokenId));

// 			_arrayRemove(msg.sender, tokenId);
// 			IERC721(nftAsset).safeTransferFrom(address(this), msg.sender, tokenId);
// 		}

// 		_checkSlots(msg.sender);

// 		users[msg.sender].power = users[msg.sender].power.sub(accPower);
// 		totalPower = totalPower.sub(accPower);
		
// 		_updateUserDebt(msg.sender, accPower, false);
// 	}

// 	function harvestAll(address to) public
// 	{
// 		for(uint i = 0; i < rewardList.length; i ++)
// 		{
// 			address token = rewardList[i];

// 			_updateReward(token);

// 			Reward memory reward = rewards[token];
// 			Staker storage user   = users[msg.sender];

// 			int256 accReward = int256(user.power.mul(reward.accRewardPerPower) / ACC_REWARD_PRECISION);
// 			uint256 _pendingReward = uint256(accReward.sub(user.rewardDebt));
// 			console.log("pending harvest reward is: %d", _pendingReward);
// 			user.rewardDebt = accReward;

// 			if(_pendingReward > 0)
// 			{
// 				IERC20(token).transfer(to, _pendingReward);
// 			}
// 		}
// 	}

// 	function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4)
// 	{
// 		return this.onERC721Received.selector;
// 	}
// }