// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DexTest.t.sol";

contract DexLiquidityTest is DexTest {
    function setUp() public override {
        super.setUp();
        
        // Create a pool for liquidity tests
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        vm.stopPrank();
    }

    function test_AddInitialLiquidity() public {
        uint128 amount0Desired = 1000e18;
        uint128 amount1Desired = 1000e18;
        
        vm.startPrank(alice);
        
        // Approve tokens
        token0.approve(address(dex), amount0Desired);
        token1.approve(address(dex), amount1Desired);
        
        // Add liquidity
        (uint256 tokenId, uint128 amount0, uint128 amount1) = dex.mint(
            address(token0),
            address(token1),
            FEE,
            -887272,  // Example ticks
            887272,
            amount0Desired,
            amount1Desired,
            0  // No lock
        );
        
        // Verify position
        IDex.Position memory position = dex.getPosition(tokenId);
        assertEq(position.owner, alice);
        assertEq(position.token0, address(token0));
        assertEq(position.token1, address(token1));
        assertTrue(position.liquidity > 0);
        assertEq(position.lowerTick, -887272);
        assertEq(position.upperTick, 887272);
        
        // Verify pool liquidity increased
        IDex.Pool memory pool = dex.getPool(address(token0), address(token1), FEE);
        assertEq(pool.liquidity, position.liquidity);
        
        // Verify NFT ownership
        assertEq(dex.ownerOf(tokenId), alice);
        
        vm.stopPrank();
    }

    function testFail_AddLiquidityInvalidTickRange() public {
        vm.startPrank(alice);
        token0.approve(address(dex), 1000e18);
        token1.approve(address(dex), 1000e18);
        
        // Try to add liquidity with invalid tick range (upper < lower)
        dex.mint(
            address(token0),
            address(token1),
            FEE,
            887272,    // Lower tick greater than upper tick
            -887272,
            1000e18,
            1000e18,
            0
        );
        vm.stopPrank();
    }

    function test_AddLiquidityWithLock() public {
        vm.startPrank(alice);
        token0.approve(address(dex), 1000e18);
        token1.approve(address(dex), 1000e18);
        
        uint256 lockPeriod = 7 days;
        (uint256 tokenId, , ) = dex.mint(
            address(token0),
            address(token1),
            FEE,
            -887272,
            887272,
            1000e18,
            1000e18,
            lockPeriod
        );
        
        assertTrue(dex.isPositionLocked(tokenId));
        
        // Try to verify lock expiration
        vm.warp(block.timestamp + lockPeriod + 1);
        assertFalse(dex.isPositionLocked(tokenId));
        
        vm.stopPrank();
    }
} 