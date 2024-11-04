// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ITimelock {
    function GRACE_PERIOD() external view returns (uint256);
    function delay() external view returns (uint256);

    function queuedTransactions(bytes32) external view returns (bool);

    function queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);
}