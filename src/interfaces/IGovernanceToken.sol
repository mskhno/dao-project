// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IGovernanceToken {
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
}
