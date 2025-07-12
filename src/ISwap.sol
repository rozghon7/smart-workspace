//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface ISwap {
    /// @notice Parameters for the swap function
    /// @param token0 The address of the first token to swap
    /// @param token1 The address of the second token to swap
    /// @param amountToken0 The amount of token0 to swap
    /// @param reserveToken0 The reserve amount of token0 in the pool
    /// @param reserveToken1 The reserve amount of token1 in the pool
    struct SwapData {
        address token0;
        address token1;
        uint256 amountToken0;
        uint256 reserveToken0;
        uint256 reserveToken1;
    }

    struct SwapRequest {
        address pool;
        address sender;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 nonce;
        uint256 deadline;
    }
}
