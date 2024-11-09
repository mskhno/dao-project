// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITimelock} from "src/interfaces/ITimelock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Timelock is ITimelock, Ownable {
    error Timelock__TransactionIsNotQueued();
    error Timelock__DelayHasNotPassed();
    error Timelock__TransactionHasExpired();
    error Timelock__TransactionExecutionReverted();

    uint256 public constant GRACE_PERIOD = 14 days;

    // governor address
    uint256 public delay;

    // quequed transactions
    // maybe add proposalId to txHash??
    mapping(bytes32 txHash => bool) public queuedTransactions;

    event QueuedTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event CancelledTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );

    constructor(uint256 _delay) Ownable(msg.sender) {
        delay = _delay;
    }

    // proposalId is debatable
    function queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        queuedTransactions[txHash] = true;

        emit QueuedTransaction(txHash, target, value, signature, data, eta);
    }

    // execute transaction
    function executeTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        // check if transaction is queued
        if (!queuedTransactions[txHash]) {
            revert Timelock__TransactionIsNotQueued();
        }
        // check if eta is passed and not expired
        if (block.timestamp < eta) {
            revert Timelock__DelayHasNotPassed();
        } else if (block.timestamp >= eta + GRACE_PERIOD) {
            revert Timelock__TransactionHasExpired();
        }

        bytes memory callData;

        // handle data
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // call
        (bool success,) = target.call{value: value}(callData);
        if (!success) {
            revert Timelock__TransactionExecutionReverted();
        }

        // emit event
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
    }
    // cancelation

    function cancelTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        queuedTransactions[txHash] = false;

        emit CancelledTransaction(txHash, target, value, signature, data, eta);
    }
}
