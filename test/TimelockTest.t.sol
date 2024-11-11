// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import {Timelock} from "src/Timelock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Box} from "test/mocks/Box.sol";

/**
 * This test suite is focused on increasing coverage on Timelock.sol,
 * since GovernorTest.t.sol is already covering a lot
 * 
 * Mainly branches testing
 */
contract TimelockTest is Test {
    Timelock public timelock;
    Box public box; 

    address public caller = makeAddr("caller");

    function setUp() public {
        timelock = new Timelock(2 days);
        box = new Box();
    }

    function test_constructor_setsDelay() public view {
        assertEq(timelock.delay(), 2 days);
    }

    function test_constructor_setsOwner() public view {
        assertEq(timelock.owner(), address(this));
    }

    /////////////
    /// onlyOwner
    /////////////

    function test_queueTransaction_onlyOwner() public {
        timelock.queueTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        timelock.queueTransaction(2, address(this), 0, "", "", block.timestamp + 1 days);
    }

    function test_executeTransaction_onlyOwner() public {
        timelock.queueTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        timelock.executeTransaction(2, address(this), 0, "", "", block.timestamp + 1 days);
    }

    function test_cancelTransaction_onlyOwner() public {
        timelock.queueTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        timelock.cancelTransaction(2, address(this), 0, "", "", block.timestamp + 1 days);
    }

    /////////////
    /// branches
    /////////////

    function test_executeTransaction_revertsWhenTransactionIsNotQueued() public {
        bytes32 txHash = keccak256(abi.encode(1, address(this), 0, "", "", block.timestamp + 1 days));
        assertEq(timelock.queuedTransactions(txHash), false);

        vm.expectRevert(Timelock.Timelock__TransactionIsNotQueued.selector);
        timelock.executeTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);
    }

    function test_executeTransaction_revertsWhenDelayHasNotPassed() public {
        timelock.queueTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);

        bytes32 txHash = keccak256(abi.encode(1, address(this), 0, "", "", block.timestamp + 1 days));
        assertEq(timelock.queuedTransactions(txHash), true);

        vm.expectRevert(Timelock.Timelock__DelayHasNotPassed.selector);
        timelock.executeTransaction(1, address(this), 0, "", "", block.timestamp + 1 days);
    }

    function test_executeTransaction_revertsWhenTransactionHasExpired() public {
        address target = address(box);
        uint256 value = 0;
        string memory signature = "store(uint256)";
        bytes memory callData = abi.encode(5);

        uint256 eta = block.timestamp + timelock.delay();

        timelock.queueTransaction(1, target, value, signature, callData, eta);

        vm.warp(block.timestamp + timelock.delay());
        vm.warp(block.timestamp + timelock.GRACE_PERIOD());

        vm.expectRevert(Timelock.Timelock__TransactionHasExpired.selector);
        timelock.executeTransaction(1, target, value, signature, callData, eta);

        // test line 70 of Timelock.sol
    }

    function test_executeTransaction_executesWhenNoSignatureProvided() public {
        address target = address(box);
        uint256 value = 0;
        string memory signature = "";
        bytes memory callData = abi.encodeWithSignature("store(uint256)", 5);

        uint256 eta = block.timestamp + timelock.delay();
        timelock.queueTransaction(1, target, value, signature, callData, eta);

        vm.warp(block.timestamp + timelock.delay());

        assertEq(box.retrieve(), 0);
        
        timelock.executeTransaction(1, target, value, signature, callData, eta);

        assertEq(box.retrieve(), 5);
    }

    function test_executeTransaction_executesWhenSignatureProvided() public {
        address target = address(box);
        uint256 value = 0;
        string memory signature = "store(uint256)";
        bytes memory callData = abi.encode(5);

        uint256 eta = block.timestamp + timelock.delay();
        timelock.queueTransaction(1, target, value, signature, callData, eta);

        vm.warp(block.timestamp + timelock.delay());

        assertEq(box.retrieve(), 0);
        
        timelock.executeTransaction(1, target, value, signature, callData, eta);

        assertEq(box.retrieve(), 5);
    }

    function test_executeTransaction_revertsWhenCallReverts() public {
        address target = address(box);
        uint256 value = 0;
        string memory signature = "store(uint226)";
        bytes memory callData = abi.encode(5);

        uint256 eta = block.timestamp + timelock.delay();
        timelock.queueTransaction(1, target, value, signature, callData, eta);

        vm.warp(block.timestamp + timelock.delay());

        assertEq(box.retrieve(), 0);
        
        vm.expectRevert(Timelock.Timelock__TransactionExecutionReverted.selector);
        timelock.executeTransaction(1, target, value, signature, callData, eta);
    }
    
    // test the rest of branches 
}