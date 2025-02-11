// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../DexTest.sol";
import "forge-std/console2.sol";

contract DexFeesTest is DexTest {
    uint256 public tokenId;
    uint256 constant INITIAL_LIQUIDITY = 100_000 * 1e18;
    uint256 constant SWAP_AMOUNT = 1000 * 1e18;
    
    function setUp() public override {
        super.setUp();
        
        // Create pool and mint position as alice
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        
        token0.approve(address(dex), INITIAL_LIQUIDITY);
        token1.approve(address(dex), INITIAL_LIQUIDITY);
        
        (tokenId, , ) = dex.mint(
            address(token0),
            address(token1),
            FEE,
            -887272,
            887272,
            uint128(INITIAL_LIQUIDITY),
            uint128(INITIAL_LIQUIDITY),
            0
        );
        vm.stopPrank();
    }

    function test_CollectFees() public {
        console2.log("\n=== Initial Setup ===");
        console2.log("Alice initial token0 balance:", token0.balanceOf(alice) / 1e18);
        console2.log("Alice initial token1 balance:", token1.balanceOf(alice) / 1e18);
        console2.log("Bob initial token0 balance:", token0.balanceOf(bob) / 1e18);
        console2.log("Bob initial token1 balance:", token1.balanceOf(bob) / 1e18);
        
        // Perform swap as bob to generate fees
        vm.startPrank(bob);
        token0.approve(address(dex), SWAP_AMOUNT);
        
        console2.log("\n=== Performing Swap ===");
        console2.log("Bob swapping token0 amount:", SWAP_AMOUNT / 1e18);
        
        uint256 bobToken1Before = token1.balanceOf(bob);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: SWAP_AMOUNT,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut = dex.swap(params);
        
        console2.log("Swap Results:");
        console2.log("- Amount in (token0):", SWAP_AMOUNT / 1e18);
        console2.log("- Amount out (token1):", amountOut / 1e18);
        console2.log("- Bob's token1 balance change:", (token1.balanceOf(bob) - bobToken1Before) / 1e18);
        vm.stopPrank();

        // Check accumulated fees before collection
        console2.log("\n=== Fees Before Collection ===");
        (uint256 feesOwed0, uint256 feesOwed1) = dex.getTokensOwed(tokenId);
        console2.log("Fees owed to position:");
        console2.log("- Token0:", feesOwed0 / 1e18);
        console2.log("- Token1:", feesOwed1 / 1e18);

        // Collect fees as alice
        vm.startPrank(alice);
        console2.log("\n=== Collecting Fees ===");
        
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);
        
        console2.log("Alice balances before collection:");
        console2.log("- Token0:", aliceToken0Before / 1e18);
        console2.log("- Token1:", aliceToken1Before / 1e18);
        
        (uint256 amount0, uint256 amount1) = dex.collectFees(tokenId);
        
        console2.log("\nCollected fees:");
        console2.log("- Token0:", amount0 / 1e18);
        console2.log("- Token1:", amount1 / 1e18);
        
        uint256 aliceToken0After = token0.balanceOf(alice);
        uint256 aliceToken1After = token1.balanceOf(alice);
        
        console2.log("\nAlice balances after collection:");
        console2.log("- Token0:", aliceToken0After / 1e18);
        console2.log("- Token1:", aliceToken1After / 1e18);
        
        // Calculate actual balance changes
        uint256 aliceDeltaToken0 = aliceToken0After - aliceToken0Before;
        uint256 aliceDeltaToken1 = aliceToken1After - aliceToken1Before;
        
        console2.log("\nBalance changes:");
        console2.log("- Token0 increase:", aliceDeltaToken0 / 1e18);
        console2.log("- Token1 increase:", aliceDeltaToken1 / 1e18);
        
        // Verify fees were reset
        console2.log("\n=== Fees After Collection ===");
        (feesOwed0, feesOwed1) = dex.getTokensOwed(tokenId);
        console2.log("Remaining fees owed:");
        console2.log("- Token0:", feesOwed0 / 1e18);
        console2.log("- Token1:", feesOwed1 / 1e18);
        
        // Final assertions
        assertEq(amount0, aliceDeltaToken0, "Token0 balance increase should match collected fees");
        assertEq(amount1, aliceDeltaToken1, "Token1 balance increase should match collected fees");
        assertEq(feesOwed0, 0, "Token0 fees should be reset to 0");
        assertEq(feesOwed1, 0, "Token1 fees should be reset to 0");
        
        vm.stopPrank();
    }

    function test_CannotCollectOthersFees() public {
        vm.startPrank(bob);
        vm.expectRevert(IDex.Unauthorized.selector);
        dex.collectFees(tokenId);
        vm.stopPrank();
    }

    function test_CollectFeesMultipleSwaps() public {
        // Perform multiple swaps
        vm.startPrank(bob);
        token0.approve(address(dex), SWAP_AMOUNT * 3);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: SWAP_AMOUNT,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        for (uint i = 0; i < 3; i++) {
            dex.swap(params);
        }
        vm.stopPrank();

        // Collect accumulated fees
        vm.startPrank(alice);
        (uint256 amount0, uint256 amount1) = dex.collectFees(tokenId);
        
        console2.log("Collected fees after multiple swaps:");
        console2.log("Token0:", amount0 / 1e18);
        console2.log("Token1:", amount1 / 1e18);
        
        // Verify fees are greater than zero
        assertGt(amount0, 0);
        vm.stopPrank();
    }
} 