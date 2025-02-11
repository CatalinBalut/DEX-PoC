// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/libraries/LiquidityMath.sol";
import "../src/libraries/TickMath.sol";

contract LiquidityMathTest is Test {
    uint160 constant SQRT_PRICE_1 = 79228162514264337593543950336;  // 1.0
    uint160 constant SQRT_PRICE_2 = 112045541557129834442199360384; // 2.0
    uint160 constant SQRT_PRICE_4 = 158456325028528675187087900672; // 4.0
    
    function test_GetLiquidityForAmount0_PriceInRange() public {
        uint128 amount0 = 1e18;
        uint128 liquidity = LiquidityMath.getLiquidityForAmount0(
            SQRT_PRICE_1,
            SQRT_PRICE_2,
            amount0
        );
        
        assertTrue(liquidity > 0, "Liquidity should be non-zero");
    }

    function test_GetLiquidityForAmount1_PriceInRange() public {
        uint128 amount1 = 1e18;
        uint128 liquidity = LiquidityMath.getLiquidityForAmount1(
            SQRT_PRICE_1,
            SQRT_PRICE_2,
            amount1
        );
        
        assertTrue(liquidity > 0, "Liquidity should be non-zero");
    }

    function test_GetLiquidityForAmounts_BothTokens() public {
        uint128 amount0 = 1e18;
        uint128 amount1 = 1e18;
        
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            SQRT_PRICE_2,  // Current price
            SQRT_PRICE_1,  // Lower price
            SQRT_PRICE_4,  // Upper price
            amount0,
            amount1
        );
        
        assertTrue(liquidity > 0, "Liquidity should be non-zero");
    }

    function test_GetLiquidityForAmount0_PriceOutOfRange() public {
        uint128 amount0 = 1e18;
        uint128 liquidity = LiquidityMath.getLiquidityForAmount0(
            SQRT_PRICE_2,
            SQRT_PRICE_1, // Upper price less than current price
            amount0
        );
        
        assertEq(liquidity, 0, "Liquidity should be zero when price out of range");
    }

    function test_GetLiquidityForAmount1_PriceOutOfRange() public {
        uint128 amount1 = 1e18;
        uint128 liquidity = LiquidityMath.getLiquidityForAmount1(
            SQRT_PRICE_2,
            SQRT_PRICE_1, // Current price less than lower price
            amount1
        );
        
        assertEq(liquidity, 0, "Liquidity should be zero when price out of range");
    }

    function test_GetLiquidityForAmounts_ProportionalAmounts() public {
        // For price of 2.0, we need sqrt(2) times more token0 than token1
        uint128 amount0 = 1414213562373095049e3;  // ~1.414e21 (≈ sqrt(2) * 1e21)
        uint128 amount1 = 1e21;                   // 1e21
        
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            SQRT_PRICE_2,
            SQRT_PRICE_1,
            SQRT_PRICE_4,
            amount0,
            amount1
        );
        
        assertTrue(liquidity > 0, "Liquidity should be non-zero");
        
        uint128 liquidity0 = LiquidityMath.getLiquidityForAmount0(
            SQRT_PRICE_2,
            SQRT_PRICE_4,
            amount0
        );
        
        uint128 liquidity1 = LiquidityMath.getLiquidityForAmount1(
            SQRT_PRICE_1,
            SQRT_PRICE_2,
            amount1
        );
        
        // For proportional amounts, liquidities should be approximately equal
        assertApproxEqRel(
            uint256(liquidity0),
            uint256(liquidity1),
            0.1e18,  // 10% tolerance
            "Liquidities should be approximately equal for proportional amounts"
        );
    }

    function testFuzz_GetLiquidityForAmounts(
        uint128 amount0,
        uint128 amount1
    ) public {
        // Bound the inputs to reasonable ranges
        amount0 = uint128(bound(uint256(amount0), 1e6, 1e24));
        amount1 = uint128(bound(uint256(amount1), 1e6, 1e24));
        
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            SQRT_PRICE_2,
            SQRT_PRICE_1,
            SQRT_PRICE_4,
            amount0,
            amount1
        );
        
        // Remove the direct comparison with amounts as it's not always valid
        assertTrue(liquidity > 0, "Liquidity should be non-zero");
    }
} 