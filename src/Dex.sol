// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";

contract Dex is IDex, ReentrancyGuard, ERC721 {
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
        require(tokenA != tokenB, "DEX: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        require(token0 != address(0), "DEX: ZERO_ADDRESS");
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
        // For now, return a simplified calculation
        // In reality, this would use the concentrated liquidity formula
        return uint128((uint256(amount0Desired) + uint256(amount1Desired)) / 2);
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external override returns (address) {
        require(fee > 0, "DEX: INVALID_FEE");
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 poolKey = _getPoolKey(token0, token1, fee);
        require(!pools[poolKey].initialized, "DEX: POOL_EXISTS");

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
        require(lowerTick < upperTick, "DEX: INVALID_TICK_RANGE");
        
        // Sort tokens and get pool
        (address token0Sorted, address token1Sorted) = _sortTokens(token0, token1);
        bytes32 poolKey = _getPoolKey(token0Sorted, token1Sorted, fee);
        Pool storage pool = pools[poolKey];
        require(pool.initialized, "DEX: POOL_NOT_INITIALIZED");

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
    ) external override returns (uint128 amount0, uint128 amount1) {
        revert("Not implemented");
    }

    function removeLiquidity(
        uint256 tokenId,
        uint128 liquidity
    ) external override returns (uint128 amount0, uint128 amount1) {
        revert("Not implemented");
    }

    function modifyPosition(
        uint256 tokenId,
        int24 newLowerTick,
        int24 newUpperTick
    ) external override returns (uint128 amount0, uint128 amount1) {
        revert("Not implemented");
    }

    function lockPosition(uint256 tokenId, uint256 lockPeriod) external override {
        revert("Not implemented");
    }

    function swap(SwapParams calldata params) external override returns (uint256 amountOut) {
        revert("Not implemented");
    }

    function getPosition(uint256 tokenId) external view override returns (Position memory) {
        // require(_exists(tokenId), "DEX: INVALID_POSITION");
        return positions[tokenId];
    }

    function getTokensOwed(uint256 tokenId) external view override returns (uint128 amount0, uint128 amount1) {
        revert("Not implemented");
    }

    function isPositionLocked(uint256 tokenId) external view override returns (bool) {
        Position memory position = positions[tokenId];
        return position.lockEndTime > block.timestamp;
    }

    function calculateSwapQuote(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        revert("Not implemented");
    }
}