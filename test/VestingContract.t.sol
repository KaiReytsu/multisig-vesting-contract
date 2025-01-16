// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VestingContract} from "../src/VestingContract.sol";
import {MockToken} from "../src/MockToken.sol";

contract VestingContractTest is Test {
    VestingContract public vestingContract;
    MockToken public token;
    
    address public owner;
    address public beneficiary;
    address public signer1;
    address public signer2;
    address public signer3;
    
    uint256 public constant INITIAL_SUPPLY = 1000000;
    uint256 public constant VESTING_AMOUNT = 100000;
    uint256 public constant REQUIRED_APPROVALS = 2;
    
    function setUp() public {
        // Setup accounts
        owner = address(this);
        beneficiary = makeAddr("beneficiary");
        signer1 = makeAddr("signer1");
        signer2 = makeAddr("signer2");
        signer3 = makeAddr("signer3");
        
        // Deploy token with 0 decimals for simplicity in testing
        token = new MockToken("Test Token", "TST", 0, INITIAL_SUPPLY);
        
        // Deploy vesting contract
        vestingContract = new VestingContract(address(token), REQUIRED_APPROVALS);
        
        // Add signers
        vestingContract.addSigner(signer1);
        vestingContract.addSigner(signer2);
        vestingContract.addSigner(signer3);
        
        // Transfer tokens to vesting contract
        token.transfer(address(vestingContract), VESTING_AMOUNT);
    }
    
    function test_InitialState() public {
        assertEq(vestingContract.owner(), owner);
        assertEq(vestingContract.tokenAddress(), address(token));
        assertEq(vestingContract.requiredApprovals(), REQUIRED_APPROVALS);
        assertEq(vestingContract.signerCount(), 4); // owner + 3 signers
        assertTrue(vestingContract.isSigner(owner));
        assertTrue(vestingContract.isSigner(signer1));
        assertTrue(vestingContract.isSigner(signer2));
        assertTrue(vestingContract.isSigner(signer3));
        assertEq(token.balanceOf(address(vestingContract)), VESTING_AMOUNT);
    }
    
    function test_AddSigner() public {
        address newSigner = makeAddr("newSigner");
        vestingContract.addSigner(newSigner);
        
        assertTrue(vestingContract.isSigner(newSigner));
        assertEq(vestingContract.signerCount(), 5);
    }
    
    function test_RemoveSigner() public {
        vestingContract.removeSigner(signer3);
        
        assertFalse(vestingContract.isSigner(signer3));
        assertEq(vestingContract.signerCount(), 3);
    }
    
    function testFail_RemoveSignerBelowRequired() public {
        // This should fail because we need at least REQUIRED_APPROVALS signers
        vestingContract.removeSigner(signer1);
        vestingContract.removeSigner(signer2);
        vestingContract.removeSigner(signer3);
    }
    
    function test_ChangeRequiredApprovals() public {
        vestingContract.changeRequiredApprovals(3);
        assertEq(vestingContract.requiredApprovals(), 3);
    }
    
    function testFail_ChangeRequiredApprovalsAboveSignerCount() public {
        vestingContract.changeRequiredApprovals(5); // Only 4 signers exist
    }
    
    function test_CreateVestingSchedule() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        (
            address schedBeneficiary,
            uint256 schedTotalAmount,
            uint256 schedStartTime,
            uint256 schedDuration,
            uint256 schedReleasedAmount,
            uint256 schedCliff,
            bool schedRevoked
        ) = getVestingSchedule();
        
        assertEq(schedBeneficiary, beneficiary);
        assertEq(schedTotalAmount, VESTING_AMOUNT);
        assertEq(schedStartTime, startTime);
        assertEq(schedDuration, duration);
        assertEq(schedReleasedAmount, 0);
        assertEq(schedCliff, cliff);
        assertFalse(schedRevoked);
    }
    
    function test_CalculateReleasableAmount() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Before cliff
        assertEq(vestingContract.calculateReleasableAmount(), 0);
        
        // After cliff but before end
        vm.warp(startTime + cliff + 1);
        uint256 expectedAmount = (VESTING_AMOUNT * (cliff + 1)) / duration;
        assertApproxEqAbs(vestingContract.calculateReleasableAmount(), expectedAmount, 1);
        
        // At half duration
        vm.warp(startTime + duration / 2);
        expectedAmount = VESTING_AMOUNT / 2;
        assertApproxEqAbs(vestingContract.calculateReleasableAmount(), expectedAmount, 1);
        
        // After duration
        vm.warp(startTime + duration + 1);
        assertEq(vestingContract.calculateReleasableAmount(), VESTING_AMOUNT);
    }
    
    function test_RequestAndApproveRelease() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Warp to halfway through vesting period
        vm.warp(startTime + duration / 2);
        
        uint256 releaseAmount = VESTING_AMOUNT / 4;
        
        // Request release as owner
        vestingContract.requestRelease(releaseAmount);
        
        // Approve as signer1
        vm.prank(signer1);
        vestingContract.approveRelease(0);
        
        // Check tokens were released
        assertEq(token.balanceOf(beneficiary), releaseAmount);
        
        // Check vesting schedule was updated
        (,,,,uint256 releasedAmount,,) = getVestingSchedule();
        assertEq(releasedAmount, releaseAmount);
    }
    
    function test_MultipleReleases() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Warp to halfway through vesting period
        vm.warp(startTime + duration / 2);
        
        uint256 firstReleaseAmount = VESTING_AMOUNT / 4;
        
        // First release
        vestingContract.requestRelease(firstReleaseAmount);
        vm.prank(signer1);
        vestingContract.approveRelease(0);
        
        // Warp to 3/4 through vesting period
        vm.warp(startTime + (duration * 3) / 4);
        
        uint256 secondReleaseAmount = VESTING_AMOUNT / 4;
        
        // Second release
        vm.prank(signer1);
        vestingContract.requestRelease(secondReleaseAmount);
        vm.prank(signer2);
        vestingContract.approveRelease(1);
        
        // Check tokens were released
        assertEq(token.balanceOf(beneficiary), firstReleaseAmount + secondReleaseAmount);
        
        // Check vesting schedule was updated
        (,,,,uint256 releasedAmount,,) = getVestingSchedule();
        assertEq(releasedAmount, firstReleaseAmount + secondReleaseAmount);
    }
    
    function testFail_RequestTooMuch() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Warp to halfway through vesting period
        vm.warp(startTime + duration / 2);
        
        // Try to release more than available
        uint256 releaseAmount = (VESTING_AMOUNT * 3) / 4; // 75% when only 50% is available
        vestingContract.requestRelease(releaseAmount);
    }
    
    function test_RevokeVesting() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Warp to halfway through vesting period
        vm.warp(startTime + duration / 2);
        
        uint256 releaseAmount = VESTING_AMOUNT / 4;
        
        // Release some tokens first
        vestingContract.requestRelease(releaseAmount);
        vm.prank(signer1);
        vestingContract.approveRelease(0);
        
        // Revoke vesting
        vestingContract.revoke();
        
        // Check vesting schedule was revoked
        (,,,,,, bool revoked) = getVestingSchedule();
        assertTrue(revoked);
        
        // Check remaining tokens were returned to owner
        uint256 expectedBalance = INITIAL_SUPPLY - VESTING_AMOUNT + (VESTING_AMOUNT - releaseAmount);
        assertEq(token.balanceOf(owner), expectedBalance);
    }
    
    function testFail_RequestAfterRevoke() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Revoke vesting
        vestingContract.revoke();
        
        // Try to request release after revoke
        vestingContract.requestRelease(1000);
    }
    
    function testFail_ApproveAfterRevoke() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        uint256 cliff = 90 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            cliff
        );
        
        // Request release
        vm.warp(startTime + duration / 2);
        vestingContract.requestRelease(1000);
        
        // Revoke vesting
        vestingContract.revoke();
        
        // Try to approve release after revoke
        vm.prank(signer1);
        vestingContract.approveRelease(0);
    }
    
    function test_OnlyOwnerFunctions() public {
        vm.prank(signer1);
        vm.expectRevert("Only owner can call this function");
        vestingContract.addSigner(makeAddr("newSigner"));
        
        vm.prank(signer1);
        vm.expectRevert("Only owner can call this function");
        vestingContract.removeSigner(signer2);
        
        vm.prank(signer1);
        vm.expectRevert("Only owner can call this function");
        vestingContract.changeRequiredApprovals(1);
        
        vm.prank(signer1);
        vm.expectRevert("Only owner can call this function");
        vestingContract.createVestingSchedule(beneficiary, 1000, block.timestamp, 365 days, 0);
        
        vm.prank(signer1);
        vm.expectRevert("Only owner can call this function");
        vestingContract.revoke();
    }
    
    function test_OnlySignerFunctions() public {
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days;
        
        vestingContract.createVestingSchedule(
            beneficiary,
            VESTING_AMOUNT,
            startTime,
            duration,
            0
        );
        
        vm.warp(startTime + duration / 2);
        
        address nonSigner = makeAddr("nonSigner");
        
        vm.prank(nonSigner);
        vm.expectRevert("Only signer can call this function");
        vestingContract.requestRelease(1000);
        
        vestingContract.requestRelease(1000);
        
        vm.prank(nonSigner);
        vm.expectRevert("Only signer can call this function");
        vestingContract.approveRelease(0);
    }
    
    // Helper function to get the vesting schedule
    function getVestingSchedule() internal view returns (
        address schedBeneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 releasedAmount,
        uint256 cliff,
        bool revoked
    ) {
        (schedBeneficiary, totalAmount, startTime, duration, releasedAmount, cliff, revoked) = vestingContract.vestingSchedule();
    }
} 