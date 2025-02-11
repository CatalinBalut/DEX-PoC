// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../DexTest.sol";
import "forge-std/console2.sol";

contract DexLockTest is DexTest {
    uint256 public tokenId;
    uint256 constant INITIAL_LIQUIDITY = 100_000 * 1e18;
    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_WEEK = 7 days;
    uint256 constant ONE_MONTH = 30 days;
    
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
            0  // No initial lock
        );
        vm.stopPrank();
    }

    function test_LockPosition() public {
        vm.startPrank(alice);
        
        // Lock position for 1 week
        dex.lockPosition(tokenId, ONE_WEEK);
        
        // Verify lock status
        assertTrue(dex.isPositionLocked(tokenId));
        
        IDex.Position memory position = dex.getPosition(tokenId);
        assertEq(position.lockPeriod, ONE_WEEK);
        assertEq(position.lockEndTime, block.timestamp + ONE_WEEK);
        
        vm.stopPrank();
    }

    function test_CannotLockAlreadyLockedPosition() public {
        vm.startPrank(alice);
        
        // Lock position first time
        dex.lockPosition(tokenId, ONE_WEEK);
        
        // Try to lock again
        vm.expectRevert(IDex.PositionCurrentlyLocked.selector);
        dex.lockPosition(tokenId, ONE_WEEK);
        
        vm.stopPrank();
    }

    function test_CannotLockOthersPosition() public {
        vm.startPrank(bob);
        
        // Try to lock alice's position
        vm.expectRevert(IDex.Unauthorized.selector);
        dex.lockPosition(tokenId, ONE_WEEK);
        
        vm.stopPrank();
    }

    function test_CannotLockWithInvalidPeriod() public {
        vm.startPrank(alice);
        
        // Try to lock with zero period
        vm.expectRevert(IDex.InvalidLockPeriod.selector);
        dex.lockPosition(tokenId, 0);
        
        // Try to lock with too long period
        vm.expectRevert(IDex.LockPeriodTooLong.selector);
        dex.lockPosition(tokenId, 366 days);
        
        vm.stopPrank();
    }

    function test_CanLockAfterPreviousLockExpires() public {
        vm.startPrank(alice);
        
        // Lock position
        dex.lockPosition(tokenId, ONE_DAY);
        
        // Fast forward past lock period
        vm.warp(block.timestamp + ONE_DAY + 1);
        
        // Should be able to lock again
        dex.lockPosition(tokenId, ONE_WEEK);
        
        // Verify new lock
        IDex.Position memory position = dex.getPosition(tokenId);
        assertEq(position.lockPeriod, ONE_WEEK);
        assertEq(position.lockEndTime, block.timestamp + ONE_WEEK);
        
        vm.stopPrank();
    }

    function test_CannotRemoveLiquidityWhileLocked() public {
        vm.startPrank(alice);
        
        // Lock position
        dex.lockPosition(tokenId, ONE_WEEK);
        
        // Try to remove liquidity
        vm.expectRevert(IDex.PositionCurrentlyLocked.selector);
        dex.removeLiquidity(tokenId, uint128(INITIAL_LIQUIDITY));
        
        vm.stopPrank();
    }

    function test_CannotAddLiquidityWhileLocked() public {
        vm.startPrank(alice);
        
        // Lock position
        dex.lockPosition(tokenId, ONE_WEEK);
        
        // Try to add liquidity
        vm.expectRevert(IDex.PositionCurrentlyLocked.selector);
        dex.addLiquidity(tokenId, uint128(INITIAL_LIQUIDITY), uint128(INITIAL_LIQUIDITY));
        
        vm.stopPrank();
    }

    function test_LockStatusOverTime() public {
        vm.startPrank(alice);
        
        // Initially not locked
        assertFalse(dex.isPositionLocked(tokenId));
        
        // Lock position
        dex.lockPosition(tokenId, ONE_MONTH);
        assertTrue(dex.isPositionLocked(tokenId));
        
        // Still locked after 29 days
        vm.warp(block.timestamp + 29 days);
        assertTrue(dex.isPositionLocked(tokenId));
        
        // Not locked after 31 days
        vm.warp(block.timestamp + 2 days);
        assertFalse(dex.isPositionLocked(tokenId));
        
        vm.stopPrank();
    }
} 