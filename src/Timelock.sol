// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITimelock} from "src/interfaces/ITimelock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Timelock
 * @dev Timelock contract for queuing and executing transactions of Governor's proposals
 */
contract Timelock is ITimelock, Ownable {
    //////////////
    // ERRORS
    //////////////
    error Timelock__TransactionIsNotQueued();
    error Timelock__DelayHasNotPassed();
    error Timelock__TransactionHasExpired();
    error Timelock__TransactionExecutionReverted();

    //////////////
    // STATE VARIABLES
    //////////////

    uint256 private immutable i_delay;
    uint256 public constant GRACE_PERIOD = 14 days;

    mapping(bytes32 txHash => bool) public queuedTransactions;

    //////////////
    // EVENTS
    //////////////
    event QueuedTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event CancelledTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta
    );

    //////////////
    // FUNCTIONS
    //////////////

    constructor(uint256 _delay) Ownable(msg.sender) {
        i_delay = _delay;
    }

    //////////////
    // EXTERNAL FUNCTIONS
    //////////////

    /**
     * @param proposalId ID of the proposal
     * @param target Address of the contract to interact with
     * @param value Value to send to the target
     * @param signature Signature of the function to call
     * @param data Data to send to the target
     * @param eta Execution Time
     *
     * @notice Queue a transaction
     *
     * @dev Queues a single transaction to be executed after the i_delay()
     * @dev proposalId is used to exclude txHash collision with other proposals who may have the same transaction,
     * though very unlikely
     */
    function queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        queuedTransactions[txHash] = true;

        emit QueuedTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @param proposalId ID of the proposal
     * @param target Address of the contract to interact with
     * @param value Value to send to the target
     * @param signature Signature of the function to call
     * @param data Data to send to the target
     * @param eta Execution Time
     *
     * @notice Execute a single transaction
     */
    function executeTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        if (!queuedTransactions[txHash]) {
            revert Timelock__TransactionIsNotQueued();
        }

        //@note можно запустить только в период [eta; GRACE_PERIOD]
        if (block.timestamp < eta) {
            revert Timelock__DelayHasNotPassed();
        } else if (block.timestamp >= eta + GRACE_PERIOD) {
            revert Timelock__TransactionHasExpired();
        }

        bytes memory callData;

        //@note норм
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        //@audit vlad. Ха-ха-ха попался, а откуда в этом контракте ETH появится а?
        // Сейчас оффлайн, поэтому не приведу примеры issues из репортов
        // Это было в Moonwell на C4, JOJO на Sherlock и ещё пару раз
        // Но это распространённая ошибка, забывают `payable receive()` добавить
        (bool success,) = target.call{value: value}(callData);
        if (!success) {
            revert Timelock__TransactionExecutionReverted();
        }

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @param proposalId ID of the proposal
     * @param target Address of the contract to interact with
     * @param value Value to send to the target
     * @param signature Signature of the function to call
     * @param data Data to send to the target
     * @param eta Execution Time
     *
     * @notice Cancel a single transaction
     */
    //@note норм
    function cancelTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyOwner {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        queuedTransactions[txHash] = false;

        emit CancelledTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @notice Get the delay
     */
    function delay() external view returns (uint256) {
        return i_delay;
    }
}
