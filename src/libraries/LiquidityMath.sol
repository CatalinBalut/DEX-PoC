// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library LiquidityMath {
    uint256 internal constant Q96 = 0x1000000000000000000000000;  // 2^96
    
    function getLiquidityForAmount0(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceUpperX96,
        uint128 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceUpperX96 <= sqrtPriceX96) return 0;
        
        uint256 intermediate = (uint256(sqrtPriceX96) * uint256(sqrtPriceUpperX96)) / Q96;
        return uint128(uint256(amount0) * intermediate / (sqrtPriceUpperX96 - sqrtPriceX96));
    }

    function getLiquidityForAmount1(
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceX96,
        uint128 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceLowerX96 >= sqrtPriceX96) return 0;
        
        return uint128(uint256(amount1) * Q96 / (sqrtPriceX96 - sqrtPriceLowerX96));
    }

    function getLiquidityForAmounts(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96,
        uint128 amount0,
        uint128 amount1
    ) internal pure returns (uint128 liquidity) {
        uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceUpperX96, amount0);
        uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceLowerX96, sqrtPriceX96, amount1);
        
        return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    }
} 