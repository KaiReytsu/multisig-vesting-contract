// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VestingContract} from "../src/VestingContract.sol";
import {MockToken} from "../src/MockToken.sol";

contract VestingContractScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the token with 0 decimals for simplicity
        MockToken token = new MockToken("Vesting Token", "VEST", 0, 1000000);
        
        // Deploy the vesting contract with 2 required approvals
        VestingContract vestingContract = new VestingContract(address(token), 2);
        
        // Add some signers (in a real deployment, these would be actual addresses)
        vestingContract.addSigner(address(0x1));
        vestingContract.addSigner(address(0x2));
        vestingContract.addSigner(address(0x3));
        
        // Transfer some tokens to the vesting contract
        token.transfer(address(vestingContract), 100000);
        
        vm.stopBroadcast();
        
        // Log the deployed addresses
        console.log("Token deployed at:", address(token));
        console.log("Vesting Contract deployed at:", address(vestingContract));
    }
} 