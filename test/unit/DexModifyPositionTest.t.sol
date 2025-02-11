// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../DexTest.t.sol";
import "forge-std/console2.sol";

contract DexModifyPositionTest is DexTest {
    uint256 public tokenId;
    uint256 constant INITIAL_LIQUIDITY = 100_000 * 1e18;
    int24 constant INITIAL_LOWER_TICK = -100;
    int24 constant INITIAL_UPPER_TICK = 100;
    
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
            INITIAL_LOWER_TICK,
            INITIAL_UPPER_TICK,
            uint128(INITIAL_LIQUIDITY),
            uint128(INITIAL_LIQUIDITY),
            0
        );
        vm.stopPrank();
    }

    function test_ModifyPosition() public {
        vm.startPrank(alice);
        
        // Get initial position details
        IDex.Position memory initialPosition = dex.getPosition(tokenId);
        console2.log("\n=== Initial Position ===");
        console2.log("Lower tick:", initialPosition.lowerTick);
        console2.log("Upper tick:", initialPosition.upperTick);
        console2.log("Liquidity:", uint256(initialPosition.liquidity) / 1e18);
        
        // Calculate new ticks maintaining same spacing
        int24 tickSpacing = INITIAL_UPPER_TICK - INITIAL_LOWER_TICK;
        int24 newLowerTick = INITIAL_LOWER_TICK + 50;  // Shift position up by 50 ticks
        int24 newUpperTick = newLowerTick + tickSpacing;
        
        console2.log("\n=== Modifying Position ===");
        console2.log("New lower tick:", newLowerTick);
        console2.log("New upper tick:", newUpperTick);
        
        (uint128 amount0, uint128 amount1) = dex.modifyPosition(
            tokenId,
            newLowerTick,
            newUpperTick
        );
        
        console2.log("Amount0 from modification:", uint256(amount0) / 1e18);
        console2.log("Amount1 from modification:", uint256(amount1) / 1e18);
        
        // Verify new position
        IDex.Position memory newPosition = dex.getPosition(tokenId);
        console2.log("\n=== New Position ===");
        console2.log("Lower tick:", newPosition.lowerTick);
        console2.log("Upper tick:", newPosition.upperTick);
        console2.log("Liquidity:", uint256(newPosition.liquidity) / 1e18);
        
        assertEq(newPosition.lowerTick, newLowerTick);
        assertEq(newPosition.upperTick, newUpperTick);
        assertEq(newPosition.upperTick - newPosition.lowerTick, tickSpacing);
        
        vm.stopPrank();
    }

    function test_CannotModifyWithDifferentSpacing() public {
        vm.startPrank(alice);
        
        int24 newLowerTick = INITIAL_LOWER_TICK + 50;
        int24 newUpperTick = INITIAL_UPPER_TICK + 100; // Different spacing
        
        vm.expectRevert(IDex.InvalidTickSpacing.selector);
        dex.modifyPosition(tokenId, newLowerTick, newUpperTick);
        
        vm.stopPrank();
    }

    function test_CannotModifyLockedPosition() public {
        vm.startPrank(alice);
        
        // Lock the position
        dex.lockPosition(tokenId, 7 days);
        
        int24 newLowerTick = INITIAL_LOWER_TICK + 50;
        int24 newUpperTick = INITIAL_UPPER_TICK + 50;
        
        vm.expectRevert(IDex.PositionCurrentlyLocked.selector);
        dex.modifyPosition(tokenId, newLowerTick, newUpperTick);
        
        vm.stopPrank();
    }

    function test_CannotModifyOthersPosition() public {
        vm.startPrank(bob);
        
        int24 newLowerTick = INITIAL_LOWER_TICK + 50;
        int24 newUpperTick = INITIAL_UPPER_TICK + 50;
        
        vm.expectRevert(IDex.Unauthorized.selector);
        dex.modifyPosition(tokenId, newLowerTick, newUpperTick);
        
        vm.stopPrank();
    }

    function test_ModifyPositionMaintainsPoolLiquidity() public {
        vm.startPrank(alice);
        
        // Get initial pool liquidity
        IDex.Pool memory pool = dex.getPool(address(token0), address(token1), FEE);
        uint128 initialPoolLiquidity = pool.liquidity;
        
        // Modify position
        int24 newLowerTick = INITIAL_LOWER_TICK + 50;
        int24 newUpperTick = INITIAL_UPPER_TICK + 50;
        
        dex.modifyPosition(tokenId, newLowerTick, newUpperTick);
        
        // Verify pool liquidity hasn't significantly changed
        pool = dex.getPool(address(token0), address(token1), FEE);
        uint128 newPoolLiquidity = pool.liquidity;
        
        assertApproxEqRel(
            uint256(newPoolLiquidity),
            uint256(initialPoolLiquidity),
            0.01e18 // 1% tolerance
        );
        
        vm.stopPrank();
    }

    function test_ModifyPositionMultipleTimes() public {
        vm.startPrank(alice);
        
        for (int24 i = 0; i < 3; i++) {
            int24 shift = i * 50;
            int24 newLowerTick = INITIAL_LOWER_TICK + shift;
            int24 newUpperTick = INITIAL_UPPER_TICK + shift;
            
            dex.modifyPosition(tokenId, newLowerTick, newUpperTick);
            
            IDex.Position memory position = dex.getPosition(tokenId);
            assertEq(position.lowerTick, newLowerTick);
            assertEq(position.upperTick, newUpperTick);
            assertEq(position.upperTick - position.lowerTick, INITIAL_UPPER_TICK - INITIAL_LOWER_TICK);
        }
        
        vm.stopPrank();
    }
} 