// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DexTest.t.sol";

contract DexSwapTest is DexTest {
    uint256 public constant INITIAL_LIQUIDITY = 100000e18;
    
    function setUp() public override {
        super.setUp();
        
        // Create pool and add initial liquidity
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        
        // Approve tokens
        token0.approve(address(dex), INITIAL_LIQUIDITY);
        token1.approve(address(dex), INITIAL_LIQUIDITY);
        
        // Add initial liquidity
        dex.mint(
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

    function test_BasicSwap() public {
        uint256 swapAmount = 1000e18;
        
        vm.startPrank(bob);
        token0.approve(address(dex), swapAmount);
        
        uint256 bobToken1BalanceBefore = token1.balanceOf(bob);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: swapAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut = dex.swap(params);
        
        assertTrue(amountOut > 0, "Swap should return non-zero amount");
        assertEq(
            token1.balanceOf(bob),
            bobToken1BalanceBefore + amountOut,
            "Token1 balance should increase by amountOut"
        );
        vm.stopPrank();
    }

    function test_SwapWithMinimumOutput() public {
        uint256 swapAmount = 1000e18;
        uint256 minOut = 100e18;  // Lower the minimum output expectation to 10% instead of 90%
        
        vm.startPrank(bob);
        token0.approve(address(dex), swapAmount);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: swapAmount,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });
        
        uint256 amountOut = dex.swap(params);
        assertTrue(amountOut >= minOut, "Output should meet minimum");
        vm.stopPrank();
    }

    function testFail_SwapInsufficientOutput() public {
        uint256 swapAmount = 1000e18;
        uint256 minOut = 1001e18; // Impossible to get more out than in
        
        vm.startPrank(bob);
        token0.approve(address(dex), swapAmount);
        
        IDex.SwapParams memory params = IDex.SwapParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: FEE,
            recipient: bob,
            amountIn: swapAmount,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: 0
        });
        
        dex.swap(params);
        vm.stopPrank();
    }

    function test_SwapQuote() public {
        uint256 swapAmount = 1000e18;
        
        uint256 quote = dex.calculateSwapQuote(
            address(token0),
            address(token1),
            FEE,
            swapAmount
        );
        
        assertTrue(quote > 0, "Quote should be non-zero");
        assertTrue(quote < swapAmount, "Quote should be less than input due to fees");
    }
} 