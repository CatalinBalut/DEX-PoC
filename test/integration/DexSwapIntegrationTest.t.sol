// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../DexTest.t.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract DexSwapIntegrationTest is DexTest {
    uint256 public constant INITIAL_LIQUIDITY = 100000e18;
    uint256 public constant SWAP_AMOUNT = 1000e18;
    uint256 public constant SMALL_SWAP_AMOUNT = 80e18;
    uint256 public tokenId;
    
    function setUp() public override {
        super.setUp();
        
        // Create pool and add initial liquidity as alice
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        
        token0.approve(address(dex), INITIAL_LIQUIDITY);
        token1.approve(address(dex), INITIAL_LIQUIDITY);
        
        console2.log("=== Initial Liquidity Addition ===");
        console2.log("Amount of token0: ", INITIAL_LIQUIDITY / 1e18);
        console2.log("Amount of token1: ", INITIAL_LIQUIDITY / 1e18);
        console2.log("Min max tick: ", -887272);
        // console2.log("Max tick: ", 887272);
        
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
        console2.log("Created position with tokenId: ", tokenId);
        vm.stopPrank();

        // Approve tokens for bob
        vm.startPrank(bob);
        token0.approve(address(dex), type(uint256).max);
        token1.approve(address(dex), type(uint256).max);
        vm.stopPrank();
    }

    function test_LargeMultipleSwaps() public {
        console2.log("=== Starting Multiple Swaps Test ===");
        
        // Initial balances
        uint256 bobInitialToken0 = token0.balanceOf(bob);
        uint256 bobInitialToken1 = token1.balanceOf(bob);
        
        console2.log("Bob's initial balances:");
        console2.log("Token0: ", bobInitialToken0 / 1e18);
        console2.log("Token1: ", bobInitialToken1 / 1e18);
        
        // First swap: token0 -> token1
        vm.startPrank(bob);
        console2.log("First Swap (token0 -> token1)");
        console2.log("Amount in: ", SWAP_AMOUNT / 1e18);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: SWAP_AMOUNT,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut1 = dex.swap(params);
        console2.log("Amount out: ", amountOut1 / 1e18);
        
        console2.log("Balances after first swap:");
        console2.log("Token0: ", token0.balanceOf(bob) / 1e18);
        console2.log("Token1: ", token1.balanceOf(bob) / 1e18);

        // Second swap: token1 -> token0
        console2.log("Second Swap (token1 -> token0)");
        console2.log("Amount in: ", amountOut1 / 1e18);
        
        params = IDex.SwapParams({
            tokenIn: address(token1),
            tokenOut: address(token0),
            fee: FEE,
            recipient: bob,
            amountIn: amountOut1,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut2 = dex.swap(params);
        console2.log("Amount out: ", amountOut2 / 1e18);
        
        console2.log("Final balances:");
        console2.log("Token0: ", token0.balanceOf(bob) / 1e18);
        console2.log("Token1: ", token1.balanceOf(bob) / 1e18);
        console2.log("Total fees paid in token0: ", (bobInitialToken0 - token0.balanceOf(bob)) / 1e18);
        
        // Verify balances after second swap
        assertEq(
            token1.balanceOf(bob),
            bobInitialToken1,
            "Token1 balance should return to initial"
        );
        assertTrue(
            token0.balanceOf(bob) < bobInitialToken0,
            "Token0 balance should be less than initial (due to fees)"
        );
    }

    function test_SmallMultipleSwaps() public {
        console2.log("=== Starting Multiple Swaps Test ===");
        
        // Initial balances
        uint256 bobInitialToken0 = token0.balanceOf(bob);
        uint256 bobInitialToken1 = token1.balanceOf(bob);
        
        console2.log("Bob's initial balances:");
        console2.log("Token0: ", bobInitialToken0 / 1e18);
        console2.log("Token1: ", bobInitialToken1 / 1e18);
        
        // First swap: token0 -> token1
        vm.startPrank(bob);
        console2.log("First Swap (token0 -> token1)");
        console2.log("Amount in: ", SMALL_SWAP_AMOUNT / 1e18);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: SMALL_SWAP_AMOUNT,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut1 = dex.swap(params);
        console2.log("Amount out: ", amountOut1 / 1e18);
        
        console2.log("Balances after first swap:");
        console2.log("Token0: ", token0.balanceOf(bob) / 1e18);
        console2.log("Token1: ", token1.balanceOf(bob) / 1e18);

        // Second swap: token1 -> token0
        console2.log("Second Swap (token1 -> token0)");
        console2.log("Amount in: ", amountOut1 / 1e18);
        
        params = IDex.SwapParams({
            tokenIn: address(token1),
            tokenOut: address(token0),
            fee: FEE,
            recipient: bob,
            amountIn: amountOut1,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut2 = dex.swap(params);
        console2.log("Amount out: ", amountOut2 / 1e18);
        
        console2.log("Final balances:");
        console2.log("Token0: ", token0.balanceOf(bob) / 1e18);
        console2.log("Token1: ", token1.balanceOf(bob) / 1e18);
        console2.log("Total fees paid in token0: ", (bobInitialToken0 - token0.balanceOf(bob)) / 1e18);
        
        // Verify balances after second swap
        assertEq(
            token1.balanceOf(bob),
            bobInitialToken1,
            "Token1 balance should return to initial"
        );
        assertTrue(
            token0.balanceOf(bob) < bobInitialToken0,
            "Token0 balance should be less than initial (due to fees)"
        );
    }

    function test_SwapAndRemoveLiquidity() public {
        console2.log("=== Starting Swap and Remove Liquidity Test ===");
        
        // Log initial position
        IDex.Position memory initialPosition = dex.getPosition(tokenId);
        console2.log("Initial position liquidity: ", uint256(initialPosition.liquidity) / 1e18);
        
        // Perform a swap first
        vm.startPrank(bob);
        console2.log("Performing swap:");
        console2.log("Swap amount: ", SWAP_AMOUNT / 1e18);
        
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
        console2.log("Amount received: ", amountOut / 1e18);
        vm.stopPrank();

        // Remove half of the liquidity
        vm.startPrank(alice);
        uint128 liquidityToRemove = uint128(INITIAL_LIQUIDITY / 2);
        console2.log("Removing liquidity:");
        console2.log("Amount to remove: ", uint256(liquidityToRemove) / 1e18);
        
        (uint128 amount0, uint128 amount1) = dex.removeLiquidity(
            tokenId,
            liquidityToRemove
        );
        
        console2.log("Tokens received:");
        console2.log("Token0: ", uint256(amount0) / 1e18);
        console2.log("Token1: ", uint256(amount1) / 1e18);
        
        // Log final position state
        IDex.Position memory finalPosition = dex.getPosition(tokenId);
        console2.log("Final position liquidity: ", uint256(finalPosition.liquidity) / 1e18);
        
        // Verify position state
        assertEq(
            finalPosition.liquidity,
            initialPosition.liquidity - liquidityToRemove,
            "Position liquidity should be halved"
        );
        vm.stopPrank();
    }
} 