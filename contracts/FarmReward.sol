pragma solidity 0.5.16;

import "./interfaces/IBEP20.sol";
import "./libraries/SafeMath.sol";
import "./utils/Ownable.sol";

contract FarmReward is Context, Ownable {
  using SafeMath for uint256;

  address public token;

  constructor(address _token) public {
    token = _token;
  }

  function remaining() external view returns (uint256) {
    return IBEP20(token).balanceOf(address(this));
  }

  function safeTransfer(address to, uint256 amount) public onlyOwner {
    uint256 _remaining = this.remaining();

    if (_remaining < amount) {
      amount = _remaining;
    }

    IBEP20(token).transfer(to, amount);
  }
}
