// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Dex.sol";
import "../src/interfaces/IDex.sol";
import "./mocks/MockERC20.sol";

contract DexTest is Test {
    Dex public dex;
    MockERC20 public token0;
    MockERC20 public token1;
    
    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    // Common test values
    uint24 public constant FEE = 300; // 0.3%
    uint160 public constant INITIAL_SQRT_PRICE = 79228162514264337593543950336; // 1:1 price
    
    function setUp() public virtual {
        // Deploy contracts
        dex = new Dex();
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");
        
        // Setup initial balances
        token0.mint(alice, 1000000e18);
        token1.mint(alice, 1000000e18);
        token0.mint(bob, 1000000e18);
        token1.mint(bob, 1000000e18);
    }
} 