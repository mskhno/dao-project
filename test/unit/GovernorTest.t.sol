// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";

import {Governor} from "src/Governor.sol";
import {GovernanceTokenMint} from "test/mocks/GovernanceTokenMint.sol";

contract GovernorTest is Test {
    Governor public governor;
    GovernanceTokenMint public token;

    address public proposer = makeAddr("proposer");

    function setUp() public {
        token = new GovernanceTokenMint(address(this));
        governor = new Governor(address(token));
    }

    modifier proposerCanPropose() {
        token.mint(proposer, governor.proposalThreshold());
        vm.prank(proposer);
        token.delegate(proposer);
        vm.roll(block.number + 1);
        _;
    }

    function test_propose_revertsWhenProposerDoesntMeetThreshold() public {
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);

        assertEq(token.getPastVotes(proposer, block.number - 1), 0);

        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ProposalThresholdNotMet.selector);
        governor.propose(targets, values, signatures, calldatas);
    }

    function test_propose_revertsWhenActionsAmountIsBad() public proposerCanPropose {
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);

        // assertEq(token.getPastVotes(proposer, block.number - 1), governor.proposalThreshold());
        // console.log(token.getPastVotes(proposer, block.number - 1));

        // revert with targets.length = 0
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__InvalidAmountOfTargets.selector);
        governor.propose(targets, values, signatures, calldatas);

        address[] memory newTargets = new address[](11);

        // revert with targets.length = 11
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__InvalidAmountOfTargets.selector);
        governor.propose(newTargets, values, signatures, calldatas);
    }

    function test_propose_revertsWhenArrayLengthsMismatch() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](0);
        string[] memory signatures = new string[](0);
        bytes[] memory calldatas = new bytes[](0);

        // revert with values.length != targets.length
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ArrayLengthsMismatch.selector);
        governor.propose(targets, values, signatures, calldatas);

        uint256[] memory newValues = new uint256[](1);

        // revert with targets.length != signatures.length
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ArrayLengthsMismatch.selector);
        governor.propose(targets, newValues, signatures, calldatas);

        string[] memory newSignatures = new string[](1);

        // revert with targets.length != calldatas.length
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ArrayLengthsMismatch.selector);
        governor.propose(targets, newValues, newSignatures, calldatas);
    }

    function test_propose_createsProposal() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 1000e18;
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        uint256 currentBlock = block.number;
        vm.prank(proposer);
        uint256 id = governor.propose(targets, values, signatures, calldatas);

        console.log("currentBlock", currentBlock);
        (
            uint256 proposalId,
            address creator,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            bool canceled,
            bool executed
        ) = governor.proposals(id);

        console.log("proposalId", proposalId);
        console.log("creator", creator);
        console.log("eta", eta);
        console.log("startBlock", startBlock);
        console.log("endBlock", endBlock);
        console.log("forVotes", forVotes);
        console.log("againstVotes", againstVotes);
        console.log("canceled", canceled);
        console.log("executed", executed);
    }
}
