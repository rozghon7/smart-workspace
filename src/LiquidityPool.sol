//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ISwap.sol";
import "./FeeManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./EIP712Swap.sol";

contract LiquidityPool is ISwap, FeeManager {
    address public sender;
    address public token0;
    uint256 public token0Decimals;
    address public token1;
    uint256 public token1Decimals;
    uint256 public reserveToken0;
    uint256 public reserveToken1;

    FeeManager public feeManager;
    EIP712Swap public eip712Swap;

    event TokenLiquidityAdded(address _tokenAddress, uint256 _amountAdded);
    event SwapCompleted(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut, uint256 _fee);

    error ReservesNotSet();
    error InsufficientTokenBalance();
    error InvalidTokenAddress(address _token);
    error InvalidTokenPair(address _tokenIn, address _tokenOut);
    error NotEnoughtTokensApproved();
    error InsufficientDexReserves();
    error InsufficientOutputAmount(uint256 _minGuaranteeAmountOut, uint256 _amountOut);
    error InsufficientLiquidity();

    constructor(address _token0, address _token1, address _feeManager) {
        token0 = _token0;
        token1 = _token1;
        feeManager = FeeManager(_feeManager);
    }

    function addTokenLiquidity(address _token, uint256 _amount) external {
        if (_token != token0 && _token != token1) {
            revert InvalidTokenAddress(_token);
        }

        if (IERC20(_token).balanceOf(msg.sender) < _amount) {
            revert InsufficientTokenBalance();
        }

        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount));

        if (_token == token0) {
            reserveToken0 = reserveToken0 + _amount;
        } else if (_token == token1) {
            reserveToken1 = reserveToken1 + _amount;
        }

        emit TokenLiquidityAdded(_token, _amount);
    }

    function getReserves() external view returns (uint256 _token1, uint256 _token2) {
        if (reserveToken0 == 0 || reserveToken1 == 0) {
            revert ReservesNotSet();
        }
        return (reserveToken0, reserveToken1);
    }

    function getPrice(address _tokenIn, address _tokenOut) external view returns (uint256 _price) {
        uint256 _reserveTokenIn = _tokenIn == token0 ? reserveToken0 : reserveToken1;
        uint256 _reserveTokenOut = _tokenOut == token0 ? reserveToken0 : reserveToken1;
        uint256 _tokenInDecimals = _tokenIn == token0 ? token0Decimals : token1Decimals;
        uint256 _tokenOutDecimals = _tokenOut == token0 ? token0Decimals : token1Decimals;

        _price = (_reserveTokenIn * 10 ** _tokenInDecimals) / (_reserveTokenOut * 10 ** _tokenOutDecimals);
    }

    function swapTokens(
        address _sender,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minGuaranteeAmountOut
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_tokenIn != token0 && _tokenIn != token1 || _tokenOut != token0 && _tokenOut != token1) {
            revert InvalidTokenPair(_tokenIn, _tokenOut);
        }
        if (_tokenIn == _tokenOut) {
            revert InvalidTokenPair(_tokenIn, _tokenOut);
        }

        address _msgSender = msg.sender == address(eip712Swap) ? _sender : msg.sender;

        if (IERC20(_tokenIn).allowance(_msgSender, address(this)) < _amountIn) {
            revert NotEnoughtTokensApproved();
        }

        uint256 _reserveTokenIn = _tokenIn == token0 ? reserveToken0 : reserveToken1;
        uint256 _reserveTokenOut = _tokenOut == token0 ? reserveToken0 : reserveToken1;
        uint256 _tokenInDecimals = _tokenIn == token0 ? token0Decimals : token1Decimals;
        uint256 _tokenOutDecimals = _tokenOut == token0 ? token0Decimals : token1Decimals;

        uint256 _amountOut = (_amountIn * (10 ** _tokenOutDecimals) * _reserveTokenOut)
            / (_reserveTokenIn + _amountIn * (10 ** _tokenOutDecimals));

        uint256 _fee = feeManager.getFee(SwapData(_tokenIn, _tokenOut, _amountIn, _reserveTokenIn, _reserveTokenOut));
        _amountOut = _amountOut - (_fee * (10 ** _tokenOutDecimals)) / (10 ** _tokenInDecimals);

        if (_amountOut < _minGuaranteeAmountOut) revert InsufficientOutputAmount(_minGuaranteeAmountOut, _amountOut);
        if (_amountOut > _reserveTokenOut) revert InsufficientLiquidity();

        require(IERC20(_tokenIn).transferFrom(_msgSender, address(this), _amountIn));
        require(IERC20(_tokenOut).transfer(_msgSender, _amountOut));

        if (_tokenIn == token0) {
            reserveToken0 = reserveToken0 + _amountIn;
            reserveToken1 = reserveToken1 - _amountOut;
        } else if (_tokenIn == token1) {
            reserveToken1 = reserveToken1 + _amountIn;
            reserveToken0 = reserveToken0 - _amountOut;
        }

        emit SwapCompleted(_tokenIn, _tokenOut, _amountIn, _amountOut, _fee);
    }
}
