// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DexTest.t.sol";

contract DexPoolTest is DexTest {
    function test_CreatePool() public {
        vm.startPrank(alice);
        address pool = dex.createPool(
            address(token0),
            address(token1),
            FEE,
            INITIAL_SQRT_PRICE
        );
        
        IDex.Pool memory poolData = dex.getPool(
            address(token0),
            address(token1),
            FEE
        );
        
        assertTrue(poolData.initialized);
        assertEq(poolData.token0, address(token0));
        assertEq(poolData.token1, address(token1));
        vm.stopPrank();
    }

    function testFail_CreateDuplicatePool() public {
        vm.startPrank(alice);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        dex.createPool(address(token0), address(token1), FEE, INITIAL_SQRT_PRICE);
        vm.stopPrank();
    }
} 