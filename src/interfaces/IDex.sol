// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDex {
    // Add these at the top of the interface, before the structs
    error IdenticalAddresses();
    error ZeroAddress();
    error InvalidFee();
    error PoolExists();
    error PoolNotInitialized();
    error InvalidTickRange();
    error InvalidAmountIn();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidPosition();
    error Unauthorized();
    error PositionCurrentlyLocked();
    error InvalidLockPeriod();
    error LockPeriodTooLong();
    error InvalidTickSpacing();

    // Structs
    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        uint256 liquidity;
        int24 lowerTick;
        int24 upperTick;
        uint256 lockPeriod;      // 0 for no lock, timestamp for time lock, type(uint256).max for eternal lock
        uint256 lockEndTime;     // When the position can be withdrawn
        uint128 tokensOwed0;     // Collected but unclaimed tokens
        uint128 tokensOwed1;
    }

    struct Pool {
        address token0;
        address token1;
        uint24 fee;              // Pool fee in basis points (1 = 0.01%)
        uint128 liquidity;       // Total liquidity in the pool
        uint160 sqrtPriceX96;    // Current price
        int24 tick;              // Current tick
        bool initialized;
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    // Events
    event PoolCreated(address indexed token0, address indexed token1, uint24 fee);
    event PositionMinted(uint256 indexed tokenId, address indexed owner, int24 lowerTick, int24 upperTick);
    event PositionBurned(uint256 indexed tokenId);
    event LiquidityAdded(uint256 indexed tokenId, uint128 liquidity);
    event LiquidityRemoved(uint256 indexed tokenId, uint128 liquidity);
    event PositionLocked(uint256 indexed tokenId, uint256 lockPeriod, uint256 lockEndTime);
    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event TicksModified(uint256 indexed tokenId, int24 newLowerTick, int24 upperTick);
    event PositionModified(
        uint256 indexed tokenId,
        int24 newLowerTick,
        int24 newUpperTick,
        uint128 newLiquidity
    );
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);

    // Pool Management
    function createPool(address token0, address token1, uint24 fee, uint160 sqrtPriceX96) external returns (address pool);
    function getPool(address token0, address token1, uint24 fee) external view returns (Pool memory);

    // Position Management
    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount0Desired,
        uint128 amount1Desired,
        uint256 lockPeriod
    ) external returns (uint256 tokenId, uint128 amount0, uint128 amount1);

    function burn(uint256 tokenId) external;

    function addLiquidity(
        uint256 tokenId,
        uint128 amount0Desired,
        uint128 amount1Desired
    ) external returns (uint128 amount0, uint128 amount1);

    function removeLiquidity(
        uint256 tokenId,
        uint128 liquidity
    ) external returns (uint128 amount0, uint128 amount1);

    // Position Modification
    function modifyPosition(
        uint256 tokenId,
        int24 newLowerTick,
        int24 newUpperTick
    ) external returns (uint128 amount0, uint128 amount1);

    function lockPosition(uint256 tokenId, uint256 lockPeriod) external;

    // Swapping
    function swap(SwapParams calldata params) external returns (uint256 amountOut);

    // View Functions
    function getPosition(uint256 tokenId) external view returns (Position memory);
    function getTokensOwed(uint256 tokenId) external view returns (uint128 amount0, uint128 amount1);
    function isPositionLocked(uint256 tokenId) external view returns (bool);
    function calculateSwapQuote(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function collectFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1);
} 