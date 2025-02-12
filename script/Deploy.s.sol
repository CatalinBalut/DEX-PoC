// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Dex.sol";
import "../test/mocks/MockERC20.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from .env
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Log initial contract size
        uint256 preSize;
        assembly {
            preSize := extcodesize(address())
        }
        console2.log("Pre-deployment contract size (KB):", preSize / 1024);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy DEX contract
        console2.log("\nDeploying DEX contract...");
        Dex dex = new Dex();
        
        // Log deployed contract size
        // uint256 postSize;
        // assembly {
        //     postSize := extcodesize(address(dex))
        // }
        // console2.log("Deployed contract size (KB):", postSize / 1024);
        console2.log("DEX deployed at:", address(dex));

        // Deploy mock tokens
        console2.log("\nDeploying mock tokens...");
        MockERC20 token0 = new MockERC20("Token A", "TKNA");
        MockERC20 token1 = new MockERC20("Token B", "TKNB");
        console2.log("Token A deployed at:", address(token0));
        console2.log("Token B deployed at:", address(token1));

        // Mint some tokens for testing
        uint256 mintAmount = 1000000 * 1e18; // 1M tokens
        console2.log("\nMinting test tokens...");
        token0.mint(msg.sender, mintAmount);
        token1.mint(msg.sender, mintAmount);
        console2.log("Minted", mintAmount / 1e18, "tokens to:", msg.sender);

        // Create initial pool
        console2.log("\nCreating initial pool...");
        uint24 fee = 300; // 0.3%
        uint160 initialSqrtPrice = 79228162514264337593543950336; // 1:1 price
        
        dex.createPool(
            address(token0),
            address(token1),
            fee,
            initialSqrtPrice
        );
        console2.log("Pool created with 0.3% fee");

        // Log final deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("DEX:", address(dex));
        console2.log("Token A:", address(token0));
        console2.log("Token B:", address(token1));
        console2.log("Initial pool created with tokens:", address(token0), "/", address(token1));
        console2.log("Pool fee:", fee);
        console2.log("Deployment complete!");

        vm.stopBroadcast();

        // // Verify the contract on BscScan Testnet
        // console2.log("\nVerifying contract on BscScan Testnet...");
        // string memory bscScanApiKey = vm.envString("BSC_TESTNET_SCAN_API_KEY");
        // string memory contractAddress = vm.toString(address(dex));  // Convert address to string
        
        // // Use the verification command
        // string memory verificationCommand = string(
        //     abi.encodePacked(
        //         "forge verify-contract ",
        //         contractAddress,
        //         " script/Deploy.s.sol:DeployScript ",
        //         bscScanApiKey,
        //         " --chain bsc-testnet"
        //     )
        // );

        // // Execute the verification command
        // string[] memory verificationArgs = new string[](1);
        // verificationArgs[0] = verificationCommand;
        // vm.ffi(verificationArgs);
        // console2.log("Verification command executed.");
    }
} 