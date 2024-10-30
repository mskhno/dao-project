// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";

import {Governor} from "src/Governor.sol";
import {GovernanceTokenMint} from "test/mocks/GovernanceTokenMint.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GovernorTest is Test {
    Governor public governor;
    GovernanceTokenMint public token;

    address public proposer;
    uint256 public proposerKey;

    bytes32 public GOVERNOR_DOMAIN_SEPARATOR;

    string public constant BALLOT_TYPEHASH = "Ballot(uint256 proposalId,bool support)";

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCasted(address voter, uint256 proposalId, bool support, uint256 votes);

    function setUp() public {
        token = new GovernanceTokenMint(address(this));

        string memory governorName = "Governor";
        string memory governorVersion = "1";

        governor = new Governor(address(token), governorName, governorVersion);

        bytes32 GOVERNOR_DOMAIN_TYPE_HASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        GOVERNOR_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                GOVERNOR_DOMAIN_TYPE_HASH,
                keccak256(bytes(governorName)),
                keccak256(bytes(governorVersion)),
                block.chainid,
                address(governor)
            )
        );

        (proposer, proposerKey) = makeAddrAndKey("proposer");
    }

    modifier proposerCanPropose() {
        token.mint(proposer, governor.proposalThreshold());
        vm.prank(proposer);
        token.delegate(proposer);
        vm.roll(block.number + 1);
        _;
    }

    modifier proposalCreated() {
        token.mint(proposer, governor.proposalThreshold());
        vm.prank(proposer);
        token.delegate(proposer);

        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 0;
        signatures[0] = "delegate(address)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        vm.prank(proposer);
        governor.propose(targets, values, signatures, calldatas);

        _;
    }

    /////////////
    /// propose()
    /////////////

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

    // function test_propose_createsProposal() public proposerCanPropose {
    //     address[] memory targets = new address[](1);
    //     uint256[] memory values = new uint256[](1);
    //     string[] memory signatures = new string[](1);
    //     bytes[] memory calldatas = new bytes[](1);

    //     targets[0] = address(token);
    //     values[0] = 1000e18;
    //     signatures[0] = "transfer(address,uint256)";
    //     calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

    //     uint256 currentBlock = block.number;
    //     vm.prank(proposer);
    //     uint256 id = governor.propose(targets, values, signatures, calldatas);

    //     uint256 expectedStartBlock = currentBlock + governor.votingDelay();
    //     uint256 expectedEndBlock = expectedStartBlock + governor.votingPeriod();

    //     (
    //         uint256 proposalId,
    //         address proposalCreator,
    //         uint256 proposalEta,
    //         uint256 proposalStartBlock,
    //         uint256 proposalEndBlock,
    //         uint256 proposalForVotes,
    //         uint256 proposalAgainstVotes,
    //         bool proposalCanceled,
    //         bool proposalExecuted
    //     ) = governor.proposals(id);

    //     assertEq(currentBlock, block.number);

    //     assertEq(proposalId, id);
    //     assertEq(proposalCreator, proposer);
    //     assertEq(proposalEta, 0);
    //     assertEq(proposalStartBlock, expectedStartBlock);
    //     assertEq(proposalEndBlock, expectedEndBlock);
    //     assertEq(proposalForVotes, 0);
    //     assertEq(proposalAgainstVotes, 0);
    //     assertEq(proposalCanceled, false);
    //     assertEq(proposalExecuted, false);

    //     (
    //         address[] memory proposalTargets,
    //         uint256[] memory proposalValues,
    //         string[] memory proposalSignatures,
    //         bytes[] memory proposalCalldatas
    //     ) = governor.getActions(id); // stack too deep

    //     assertEq(proposalTargets.length, targets.length);
    //     assertEq(proposalValues.length, values.length);
    //     assertEq(proposalSignatures.length, signatures.length);
    //     assertEq(proposalCalldatas.length, calldatas.length);

    //     assertEq(proposalTargets[0], targets[0]);
    //     assertEq(proposalValues[0], values[0]);
    //     assertEq(keccak256(abi.encode(proposalSignatures[0])), keccak256(abi.encode(signatures[0])));
    //     assertEq(proposalCalldatas[0], calldatas[0]);
    // }

    function test_propose_emitsEvent() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 1000e18;
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        uint256 startBlock = block.number + governor.votingDelay();
        uint256 endBlock = startBlock + governor.votingPeriod();

        vm.prank(proposer);
        vm.expectEmit(false, false, false, true);
        emit ProposalCreated(1, proposer, targets, values, signatures, calldatas, startBlock, endBlock);
        governor.propose(targets, values, signatures, calldatas);
    }

    function test_propose_revertsWhenProposerHasLiveProposalPending() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 1000e18;
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        vm.prank(proposer);
        governor.propose(targets, values, signatures, calldatas);

        assertEq(uint256(Governor.ProposalState.Pending), uint256(governor.state(1)));

        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ProposerHasLiveProposal.selector);
        governor.propose(targets, values, signatures, calldatas);
    }

    function test_propose_revertsWhenProposerHasLiveProposalActive() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 1000e18;
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        vm.prank(proposer);
        governor.propose(targets, values, signatures, calldatas);

        vm.roll(block.number + 1);

        assertEq(uint256(Governor.ProposalState.Active), uint256(governor.state(1)));

        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ProposerHasLiveProposal.selector);
        governor.propose(targets, values, signatures, calldatas);
    }

    /////////////
    /// getActions()
    /////////////

    function test_getActions_revertsWhenProposalIdIsInvalid() public proposalCreated {
        assertEq(governor.proposalCount(), 1);

        vm.expectRevert(Governor.Governor__InvalidProposalId.selector);
        governor.getActions(0);

        vm.expectRevert(Governor.Governor__InvalidProposalId.selector);
        governor.getActions(2);
    }

    function test_getActions_returnsRightActions() public proposerCanPropose {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(token);
        values[0] = 1000e18;
        signatures[0] = "transfer(address,uint256)";
        calldatas[0] = abi.encodeWithSignature(signatures[0], proposer, values[0]);

        vm.prank(proposer);
        uint256 id = governor.propose(targets, values, signatures, calldatas);

        (
            address[] memory proposalTargets,
            uint256[] memory proposalValues,
            string[] memory proposalSignatures,
            bytes[] memory proposalCalldatas
        ) = governor.getActions(id);

        assertEq(proposalTargets[0], targets[0]);
        assertEq(proposalValues[0], values[0]);
        assertEq(keccak256(abi.encode(proposalSignatures[0])), keccak256(abi.encode(signatures[0])));
        assertEq(proposalCalldatas[0], calldatas[0]);
    }

    /////////////
    /// state()
    /////////////

    function test_state_revertsWhenProposalIdIsInvalid() public proposalCreated {
        assertEq(governor.proposalCount(), 1);

        vm.expectRevert(Governor.Governor__InvalidProposalId.selector);
        governor.state(0);

        vm.expectRevert(Governor.Governor__InvalidProposalId.selector);
        governor.state(2);
    }

    function test_state_returnsPending() public proposalCreated {
        assertEq(governor.proposalCount(), 1);

        Governor.ProposalState actualState = governor.state(1);

        assertEq(uint256(actualState), uint256(Governor.ProposalState.Pending));
    }

    function test_state_returnsActive() public proposalCreated {
        assertEq(governor.proposalCount(), 1);

        vm.roll(block.number + 1);

        Governor.ProposalState actualState = governor.state(1);

        assertEq(uint256(actualState), uint256(Governor.ProposalState.Active));
    }

    /////////////
    /// castVote()
    /////////////

    function test_castVote_revertsWhenProposalIsNotActive() public proposalCreated {
        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__ProposalIsNotActive.selector);
        governor.castVote(1, true);
    }

    function test_castVote_UserCanVote() public proposalCreated {
        vm.roll(block.number + 1);

        (,,,,, uint256 initialForVotes,,,) = governor.proposals(1);

        assertEq(initialForVotes, 0);

        Governor.Receipt memory blankReceipt = governor.getReceipt(1, proposer);

        assertEq(blankReceipt.hasVoted, false);
        assertEq(blankReceipt.support, false);
        assertEq(blankReceipt.votes, 0);

        uint256 expectedForVotes = token.getPastVotes(proposer, block.number - 1);

        vm.prank(proposer);
        governor.castVote(1, true);

        (,,,,, uint256 actualForVotes,,,) = governor.proposals(1);

        Governor.Receipt memory receipt = governor.getReceipt(1, proposer);

        assertEq(actualForVotes, expectedForVotes);
        assertEq(actualForVotes, expectedForVotes - initialForVotes);

        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, true);
        assertEq(receipt.votes, expectedForVotes);
    }

    function test_castVote_revertsWhenUserHasVoted() public proposalCreated {
        vm.roll(block.number + 1);

        vm.prank(proposer);
        governor.castVote(1, true);

        vm.prank(proposer);
        vm.expectRevert(Governor.Governor__AddressAlreadyVoted.selector);
        governor.castVote(1, true);
    }

    function test_castVote_emitsEvent() public proposalCreated {
        vm.roll(block.number + 1);

        console.log("proposer balance:", token.balanceOf(proposer));
        console.log("proposer votes:", token.getPastVotes(proposer, block.number - 1));

        vm.prank(proposer);
        vm.expectEmit(false, false, false, true);
        emit VoteCasted(proposer, 1, true, 1000);
        governor.castVote(1, true);
    }

    /////////////
    /// castVote()
    /////////////

    function test_castVoteBySig_castsVote() public proposalCreated {
        vm.roll(block.number + 1);

        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, 1, true));
        bytes32 digest = MessageHashUtils.toTypedDataHash(GOVERNOR_DOMAIN_SEPARATOR, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proposerKey, digest);

        (,,,,, uint256 initialForVotes,,,) = governor.proposals(1);

        assertEq(initialForVotes, 0);

        Governor.Receipt memory blankReceipt = governor.getReceipt(1, proposer);

        assertEq(blankReceipt.hasVoted, false);
        assertEq(blankReceipt.support, false);
        assertEq(blankReceipt.votes, 0);

        uint256 expectedForVotes = token.getPastVotes(proposer, block.number - 1);

        governor.castVoteBySig(1, true, v, r, s);

        (,,,,, uint256 actualForVotes,,,) = governor.proposals(1);

        Governor.Receipt memory receipt = governor.getReceipt(1, proposer);

        assertEq(actualForVotes, expectedForVotes);
        assertEq(actualForVotes, expectedForVotes - initialForVotes);

        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, true);
        assertEq(receipt.votes, expectedForVotes);
    }
}
