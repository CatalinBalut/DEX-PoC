// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";
import { TickMath } from "./libraries/TickMath.sol";
import { LiquidityMath } from "./libraries/LiquidityMath.sol";

contract Dex is IDex, ReentrancyGuard, ERC721 {
    uint256 internal constant Q96 = 0x1000000000000000000000000;  // 2^96
    
    // State variables
    mapping(bytes32 => Pool) public pools;
    mapping(uint256 => Position) public positions;
    uint256 private _nextTokenId;
    
    constructor() ERC721("Dex Position", "DPOS") {}

    // Helper function to generate pool key
    function _getPoolKey(
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1, fee));
    }
    
    // Helper to ensure tokens are sorted
    function _sortTokens(address tokenA, address tokenB) internal pure 
        returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        return (token0, token1);
    }

    // Helper function to calculate liquidity from amounts and price range
    function _calculateLiquidity(
        uint160 sqrtPriceX96,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount0Desired,
        uint128 amount1Desired
    ) internal pure returns (uint128 liquidity) {
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(upperTick);
        
        return LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            amount0Desired,
            amount1Desired
        );
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external override returns (address) {
        if (fee == 0) revert InvalidFee();
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 poolKey = _getPoolKey(token0, token1, fee);
        if (pools[poolKey].initialized) revert PoolExists();

        pools[poolKey] = Pool({
            token0: token0,
            token1: token1,
            fee: fee,
            liquidity: 0,
            sqrtPriceX96: sqrtPriceX96,
            tick: 0, // We'll implement tick calculation later
            initialized: true
        });

        emit PoolCreated(token0, token1, fee);
        return address(this);
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view override returns (Pool memory) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return pools[_getPoolKey(token0, token1, fee)];
    }

    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount0Desired,
        uint128 amount1Desired,
        uint256 lockPeriod
    ) external override nonReentrant returns (
        uint256 tokenId,
        uint128 amount0,
        uint128 amount1
    ) {
        if (lowerTick >= upperTick) revert InvalidTickRange();
        
        // Sort tokens and get pool
        (address token0Sorted, address token1Sorted) = _sortTokens(token0, token1);
        bytes32 poolKey = _getPoolKey(token0Sorted, token1Sorted, fee);
        Pool storage pool = pools[poolKey];
        if (!pool.initialized) revert PoolNotInitialized();

        // Transfer tokens to contract
        if (amount0Desired > 0) {
            IERC20(token0Sorted).transferFrom(msg.sender, address(this), amount0Desired);
        }
        if (amount1Desired > 0) {
            IERC20(token1Sorted).transferFrom(msg.sender, address(this), amount1Desired);
        }

        // Calculate liquidity amount
        uint128 liquidity = _calculateLiquidity(
            pool.sqrtPriceX96,
            lowerTick,
            upperTick,
            amount0Desired,
            amount1Desired
        );

        // Mint NFT position
        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        // Store position
        positions[tokenId] = Position({
            owner: msg.sender,
            token0: token0Sorted,
            token1: token1Sorted,
            fee: fee,
            liquidity: liquidity,
            lowerTick: lowerTick,
            upperTick: upperTick,
            lockPeriod: lockPeriod,
            lockEndTime: lockPeriod > 0 ? block.timestamp + lockPeriod : 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        // Update pool liquidity
        pool.liquidity += liquidity;

        emit PositionMinted(tokenId, msg.sender, lowerTick, upperTick);
        
        return (tokenId, amount0Desired, amount1Desired);
    }

    function burn(uint256 tokenId) external override {
        revert("Not implemented");
    }

    function addLiquidity(
        uint256 tokenId,
        uint128 amount0Desired,
        uint128 amount1Desired
    ) external override nonReentrant returns (uint128 amount0, uint128 amount1) {
        Position storage position = positions[tokenId];
        if (position.owner != msg.sender) revert Unauthorized();
        if (position.lockEndTime > block.timestamp) revert PositionCurrentlyLocked();

        bytes32 poolKey = _getPoolKey(position.token0, position.token1, position.fee);
        Pool storage pool = pools[poolKey];

        // Calculate new liquidity amount
        uint128 newLiquidity = _calculateLiquidity(
            pool.sqrtPriceX96,
            position.lowerTick,
            position.upperTick,
            amount0Desired,
            amount1Desired
        );

        // Transfer tokens to contract
        if (amount0Desired > 0) {
            IERC20(position.token0).transferFrom(msg.sender, address(this), amount0Desired);
        }
        if (amount1Desired > 0) {
            IERC20(position.token1).transferFrom(msg.sender, address(this), amount1Desired);
        }

        // Update position and pool liquidity
        position.liquidity += newLiquidity;
        pool.liquidity += newLiquidity;

        emit LiquidityAdded(tokenId, newLiquidity);
        return (amount0Desired, amount1Desired);
    }

    function removeLiquidity(
        uint256 tokenId,
        uint128 liquidityAmount
    ) external override nonReentrant returns (uint128 amount0, uint128 amount1) {
        Position storage position = positions[tokenId];
        if (position.owner != msg.sender) revert Unauthorized();
        if (position.lockEndTime > block.timestamp) revert PositionCurrentlyLocked();
        if (liquidityAmount > position.liquidity) revert InsufficientLiquidity();

        bytes32 poolKey = _getPoolKey(position.token0, position.token1, position.fee);
        Pool storage pool = pools[poolKey];

        // Calculate amounts using proper price ratio
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(position.lowerTick);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(position.upperTick);
        
        amount0 = uint128(uint256(liquidityAmount) * (sqrtRatioBX96 - sqrtRatioAX96) / pool.sqrtPriceX96);
        amount1 = uint128(uint256(liquidityAmount) * (pool.sqrtPriceX96 - sqrtRatioAX96) / Q96);

        position.liquidity -= liquidityAmount;
        pool.liquidity -= liquidityAmount;

        IERC20(position.token0).transfer(msg.sender, amount0);
        IERC20(position.token1).transfer(msg.sender, amount1);

        emit LiquidityRemoved(tokenId, liquidityAmount);
        return (amount0, amount1);
    }

    function modifyPosition(
        uint256 tokenId,
        int24 newLowerTick,
        int24 newUpperTick
    ) external override nonReentrant returns (uint128 amount0, uint128 amount1) {
        Position storage position = positions[tokenId];
        
        // Check ownership and lock status
        if (position.owner != msg.sender) revert Unauthorized();
        if (position.lockEndTime > block.timestamp) revert PositionCurrentlyLocked();
        
        // Verify tick range
        if (newLowerTick >= newUpperTick) revert InvalidTickRange();
        
        // Check that the new position maintains the same tick spacing
        int24 oldTickSpacing = position.upperTick - position.lowerTick;
        int24 newTickSpacing = newUpperTick - newLowerTick;
        if (oldTickSpacing != newTickSpacing) revert InvalidTickSpacing();
        
        bytes32 poolKey = _getPoolKey(position.token0, position.token1, position.fee);
        Pool storage pool = pools[poolKey];
        
        // Remove liquidity from old position
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(position.lowerTick);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(position.upperTick);
        
        // Calculate amounts to remove based on current position
        amount0 = uint128(uint256(position.liquidity) * (sqrtRatioBX96 - sqrtRatioAX96) / pool.sqrtPriceX96);
        amount1 = uint128(uint256(position.liquidity) * (pool.sqrtPriceX96 - sqrtRatioAX96) / Q96);
        
        // Update pool liquidity
        pool.liquidity = uint128(uint256(pool.liquidity) - position.liquidity);
        
        // Calculate new liquidity for new position
        uint128 newLiquidity = _calculateLiquidity(
            pool.sqrtPriceX96,
            newLowerTick,
            newUpperTick,
            amount0,
            amount1
        );
        
        // Update position with new ticks and liquidity
        position.lowerTick = newLowerTick;
        position.upperTick = newUpperTick;
        position.liquidity = newLiquidity;
        
        // Update pool with new liquidity
        pool.liquidity += newLiquidity;
        
        emit PositionModified(
            tokenId,
            newLowerTick,
            newUpperTick,
            newLiquidity
        );
        
        return (amount0, amount1);
    }

    function lockPosition(uint256 tokenId, uint256 lockPeriod) external override {
        Position storage position = positions[tokenId];
        
        // Check ownership
        if (position.owner != msg.sender) revert Unauthorized();
        
        // Check if position is not already locked
        if (position.lockEndTime > block.timestamp) revert PositionCurrentlyLocked();
        
        // Check if lock period is valid (e.g., not too long)
        if (lockPeriod == 0) revert InvalidLockPeriod();
        if (lockPeriod > 365 days) revert LockPeriodTooLong();
        
        // Set the lock end time
        position.lockPeriod = lockPeriod;
        position.lockEndTime = block.timestamp + lockPeriod;
        
        emit PositionLocked(tokenId, lockPeriod, position.lockEndTime);
    }
    
    // Helper function to calculate amount out based on liquidity and price change
    function _calculateAmountOut(
        uint256 amountIn,
        uint128 liquidity,
        uint160 sqrtPriceX96,
        uint24 fee
    ) internal pure returns (uint256 amountOut) {
        // Calculate virtual reserves
        uint256 virtualReserve0 = uint256(liquidity) * Q96 / sqrtPriceX96;
        uint256 virtualReserve1 = uint256(liquidity) * sqrtPriceX96 / Q96;
        
        // Calculate output before fees
        amountOut = (amountIn * virtualReserve1) / (virtualReserve0 + amountIn);
        
        // Apply fee after price impact calculation
        amountOut = (amountOut * (10000 - fee)) / 10000;
    }

    function swap(SwapParams calldata params) external override nonReentrant returns (uint256 amountOut) {
        if (params.amountIn == 0) revert InvalidAmountIn();
        
        // Sort tokens and get pool
        (address token0, address token1) = _sortTokens(params.tokenIn, params.tokenOut);
        bytes32 poolKey = _getPoolKey(token0, token1, params.fee);
        Pool storage pool = pools[poolKey];
        if (!pool.initialized) revert PoolNotInitialized();
        if (pool.liquidity == 0) revert InsufficientLiquidity();

        // Calculate amount out
        amountOut = _calculateAmountOut(
            params.amountIn,
            pool.liquidity,
            pool.sqrtPriceX96,
            params.fee
        );
        if (amountOut < params.amountOutMinimum) revert InsufficientOutputAmount();

        // Transfer tokens
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);

        // Update pool price (simplified for now)
        // In reality, would update based on concentrated liquidity formula
        pool.sqrtPriceX96 = uint160(
            (uint256(pool.sqrtPriceX96) * (params.amountIn + pool.liquidity)) / 
            (amountOut + pool.liquidity)
        );

        emit Swap(
            msg.sender,
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            amountOut
        );

        return amountOut;
    }

    function calculateSwapQuote(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        bytes32 poolKey = _getPoolKey(token0, token1, fee);
        Pool memory pool = pools[poolKey];
        if (!pool.initialized) revert PoolNotInitialized();
        if (pool.liquidity == 0) revert InsufficientLiquidity();

        return _calculateAmountOut(
            amountIn,
            pool.liquidity,
            pool.sqrtPriceX96,
            fee
        );
    }

    function getPosition(uint256 tokenId) external view override returns (Position memory) {
        // if (!_exists(tokenId)) revert InvalidPosition();
        return positions[tokenId];
    }

    function getTokensOwed(uint256 tokenId) external view override returns (uint128 amount0, uint128 amount1) {
        revert("Not implemented");
    }

    function isPositionLocked(uint256 tokenId) external view override returns (bool) {
        Position memory position = positions[tokenId];
        return position.lockEndTime > block.timestamp;
    }
}