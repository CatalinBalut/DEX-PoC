// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DexTest.t.sol";

contract DexTestUtils is DexTest {
    // Helper to setup a pool with initial liquidity
    function setupPoolWithLiquidity(
        uint128 amount0,
        uint128 amount1
    ) internal returns (uint256 tokenId) {
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        
        // Add initial liquidity
        token0.approve(address(dex), amount0);
        token1.approve(address(dex), amount1);
        
        (tokenId, , ) = dex.mint(
            address(token0),
            address(token1),
            FEE,
            -887272,  // Example ticks
            887272,
            amount0,
            amount1,
            0
        );
        vm.stopPrank();
    }

    // Helper to perform swaps
    function performSwap(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        vm.startPrank(user);
        IERC20(tokenIn).approve(address(dex), amountIn);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: FEE,
            recipient: user,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        amountOut = dex.swap(params);
        vm.stopPrank();
    }
} 