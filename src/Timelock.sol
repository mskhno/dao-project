// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ITimelock} from "./interfaces/ITimelock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Timelock is ITimelock, Ownable {
    error Timelock__CallerMustBeGovernor();

    uint256 public constant GRACE_PERIOD = 14 days;

    // governor address
    uint256 public delay;

    // quequed transactions
    // maybe add proposalId to txHash??
    mapping(bytes32 txHash => bool) public queuedTransactions;

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
    ) public onlyOwner returns (bytes32) {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        queuedTransactions[txHash] = true;

        return txHash;
    }
}
