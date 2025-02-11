// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/DexTestUtils.t.sol";

contract DexIntegrationTest is DexTestUtils {
    function test_FullFlow() public {
        // Test complete flow: create pool -> add liquidity -> swap -> remove liquidity
        uint256 tokenId = setupPoolWithLiquidity(1000e18, 1000e18);
        
        // Perform swap
        uint256 amountOut = performSwap(bob, address(token0), address(token1), 100e18);
        
        // Remove liquidity
        vm.startPrank(alice);
        (uint128 amount0, uint128 amount1) = dex.removeLiquidity(tokenId, 1000e18);
        vm.stopPrank();
        
        // Assert final states
        assertTrue(amount0 > 0);
        assertTrue(amount1 > 0);
    }
} 