// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceTokenMint} from "./GovernanceTokenMint.sol";

contract GovernanceTokenMintTest is Test {
    GovernanceTokenMint token;

    uint256 mintAmount = 1000e18;
    address user = makeAddr("user");
    address delegate = makeAddr("delegate");

    function setUp() public {
        token = new GovernanceTokenMint(user, mintAmount);
    }

    function testVotes() public {
        // mint did not create a checkpoint
        uint256 balance = token.balanceOf(user);
        console.log("balance", balance);
        uint256 votes = token.getVotes(user);
        console.log("votes", votes);

        vm.roll(block.number + 100);
        uint256 totalSupply = token.getPastTotalSupply(block.number - 1);
        console.log("totalSupply", totalSupply);

        // self delegation created a checkpoint
        console.log("SELF-DELEGATION CHECK");
        vm.prank(user);
        token.delegate(user);
        votes = token.getVotes(user);
        address delegatee = token.delegates(user);
        console.log("user", user);
        console.log("delegatee", delegatee);
        console.log("votes", votes);
    }

    // votes are increased after transfer only if the recipient has delegated
    function testTransfer() public {
        vm.prank(user);
        token.delegate(user);

        vm.prank(delegate);
        token.delegate(delegate);

        uint256 userBalance = token.balanceOf(user);
        address userDelegatee = token.delegates(user);
        uint256 userVotes = token.getVotes(user);

        console.log("USER STATS at block", block.number);
        console.log("balance", userBalance);
        console.log("delegatee", userDelegatee);
        console.log("votes", userVotes);

        uint256 delegateBalance = token.balanceOf(delegate);
        address delegateDelegatee = token.delegates(delegate);
        uint256 delegateVotes = token.getVotes(delegate);

        console.log("DELEGATE STATS at block", block.number);
        console.log("balance", delegateBalance);
        console.log("delegatee", delegateDelegatee);
        console.log("votes", delegateVotes);

        vm.roll(block.number + 9);
        vm.prank(user);
        token.transfer(delegate, 100e18);

        delegateBalance = token.balanceOf(delegate);
        delegateDelegatee = token.delegates(delegate);
        delegateVotes = token.getVotes(delegate);

        console.log("DELEGATE STATS AFTER TRANSFER at block", block.number);
        console.log("balance", delegateBalance);
        console.log("delegatee", delegateDelegatee);
        console.log("votes", delegateVotes);

        console.log("USER PAST VOTES at block", block.number);
        uint256 userPastVotes = token.getPastVotes(user, block.number - 1);
        console.log("pastVotes", userPastVotes);
    }

    // at block 1
    // user has 1000 tokens
    // user votes is 1000
    // at block 2
    // user transfer 500 tokens to delegate
    // user votes is 500
    // delegate votes is 500
    // at block 3
    // user transfer 500 tokens to delegate
    // user votes is 0
    // delegate votes is 1000

    // to access all the past votes need to be at block 4(3 + 1)
    function testCheckpoint() public {
        vm.prank(user);
        token.delegate(user);

        vm.prank(delegate);
        token.delegate(delegate);

        uint256 userVotes = token.getVotes(user);
        uint256 delegateVotes = token.getVotes(delegate);
        console.log("VOTES AT BLOCK", block.number);
        console.log("user", userVotes);
        console.log("delegate", delegateVotes);
        console.log("");

        vm.roll(block.number + 1);
        vm.prank(user);
        token.transfer(delegate, 500e18);

        userVotes = token.getVotes(user);
        delegateVotes = token.getVotes(delegate);
        console.log("VOTES AT BLOCK", block.number);
        console.log("user", userVotes);
        console.log("delegate", delegateVotes);
        console.log("");

        vm.roll(block.number + 1);
        vm.prank(user);
        token.transfer(delegate, 500e18);

        userVotes = token.getVotes(user);
        delegateVotes = token.getVotes(delegate);
        console.log("VOTES AT BLOCK", block.number);
        console.log("user", userVotes);
        console.log("delegate", delegateVotes);
        console.log("");

        vm.roll(block.number + 1);
        console.log("AT BLOCK", block.number);
        console.log("");

        uint256 userPastVotes = token.getPastVotes(user, 1);
        uint256 delegatePastVotes = token.getPastVotes(delegate, 1);
        console.log("CHECKING PAST VOTES AT BLOCK 1");
        console.log("user", userPastVotes);
        console.log("delegate", delegatePastVotes);
        console.log("");

        userPastVotes = token.getPastVotes(user, 2);
        delegatePastVotes = token.getPastVotes(delegate, 2);
        console.log("CHECKING PAST VOTES AT BLOCK 2");
        console.log("user", userPastVotes);
        console.log("delegate", delegatePastVotes);
        console.log("");

        userPastVotes = token.getPastVotes(user, 3);
        delegatePastVotes = token.getPastVotes(delegate, 3);
        console.log("CHECKING PAST VOTES AT BLOCK 3");
        console.log("user", userPastVotes);
        console.log("delegate", delegatePastVotes);
    }

    function testZeroCheckpoints() public {
        // no delegation from user
        vm.prank(delegate);
        token.delegate(delegate);

        vm.prank(user);
        token.transfer(delegate, 1000e18);

        vm.roll(block.number + 1);
        uint256 userPastVotes = token.getPastVotes(user, 1);
        uint256 delegatePastVotes = token.getPastVotes(delegate, 1);
        // should be zero
        console.log("userPastVotes", userPastVotes);
        console.log("delegatePastVotes", delegatePastVotes);

        vm.roll(block.number + 1);
        delegatePastVotes = token.getPastVotes(delegate, 2);
        // should be 1000
        console.log("delegatePastVotes at 2", delegatePastVotes);
    }
}
