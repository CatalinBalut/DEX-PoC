// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DexTest.t.sol";
import "forge-std/console2.sol";

contract DexLiquidityIntegrationTest is DexTest {
    uint256 public tokenId;
    uint256 constant SWAP_AMOUNT = 1000 * 1e18;
    uint256 constant INITIAL_LIQUIDITY = 100_000 * 1e18;
    uint256 constant ADDITIONAL_LIQUIDITY = 100_000 * 1e18;

    function setUp() public override {
        super.setUp();
        
        // Create pool and add initial liquidity as alice
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        
        token0.approve(address(dex), INITIAL_LIQUIDITY);
        token1.approve(address(dex), INITIAL_LIQUIDITY);
        
        console2.log("\n=== Initial Setup ===");
        console2.log("Initial liquidity: ", INITIAL_LIQUIDITY / 1e18);
        
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

    function test_SwapBeforeAndAfterAddingLiquidity() public {
        // First swap with initial liquidity
        vm.startPrank(bob);
        uint256 largerSwapAmount = 50_000 * 1e18; // Much larger swap (50% of pool)
        token0.approve(address(dex), largerSwapAmount);
        
        console2.log("\n=== Initial Pool State ===");
        console2.log("Initial token0 in pool: ", token0.balanceOf(address(dex)) / 1e18);
        console2.log("Initial token1 in pool: ", token1.balanceOf(address(dex)) / 1e18);
        
        console2.log("\n=== First Swap (Before Adding Liquidity) ===");
        console2.log("Swap amount: ", largerSwapAmount / 1e18);
        
        uint256 bobInitialToken1 = token1.balanceOf(bob);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: largerSwapAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut1 = dex.swap(params);
        uint256 firstSwapReceived = token1.balanceOf(bob) - bobInitialToken1;
        
        console2.log("Amount received from first swap: ", firstSwapReceived / 1e18);
        console2.log("Pool balances after first swap:");
        console2.log("Token0: ", token0.balanceOf(address(dex)) / 1e18);
        console2.log("Token1: ", token1.balanceOf(address(dex)) / 1e18);
        vm.stopPrank();

        // Add more liquidity (5x the initial amount)
        vm.startPrank(alice);
        uint256 largerAdditionalLiquidity = INITIAL_LIQUIDITY * 5;
        token0.approve(address(dex), largerAdditionalLiquidity);
        token1.approve(address(dex), largerAdditionalLiquidity);
        
        console2.log("\n=== Adding More Liquidity ===");
        console2.log("Additional liquidity tokens: ", largerAdditionalLiquidity / 1e18);
        
        dex.addLiquidity(
            tokenId,
            uint128(largerAdditionalLiquidity),
            uint128(largerAdditionalLiquidity)
        );
        
        console2.log("Pool balances after addition:");
        console2.log("Token0: ", token0.balanceOf(address(dex)) / 1e18);
        console2.log("Token1: ", token1.balanceOf(address(dex)) / 1e18);
        vm.stopPrank();

        // Second swap with increased liquidity
        vm.startPrank(bob);
        token0.approve(address(dex), largerSwapAmount);
        
        console2.log("\n=== Second Swap (After Adding Liquidity) ===");
        console2.log("Swap amount: ", largerSwapAmount / 1e18);
        
        bobInitialToken1 = token1.balanceOf(bob);
        params.amountIn = largerSwapAmount;
        uint256 amountOut2 = dex.swap(params);
        
        uint256 secondSwapReceived = token1.balanceOf(bob) - bobInitialToken1;
        console2.log("Amount received from second swap: ", secondSwapReceived / 1e18);
        console2.log("Pool balances after second swap:");
        console2.log("Token0: ", token0.balanceOf(address(dex)) / 1e18);
        console2.log("Token1: ", token1.balanceOf(address(dex)) / 1e18);
        
        console2.log("\n=== Comparison ===");
        console2.log("First swap output: ", firstSwapReceived / 1e18);
        console2.log("Second swap output: ", secondSwapReceived / 1e18);
        console2.log("Difference: ", (secondSwapReceived - firstSwapReceived) / 1e18);
        console2.log("Improvement percentage: ", ((secondSwapReceived - firstSwapReceived) * 100) / firstSwapReceived, "%");
        
        // Assert that second swap has less price impact
        assertGt(secondSwapReceived, firstSwapReceived, "Second swap should return more tokens");
        vm.stopPrank();
    }
} 