// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract Governor {
    error Governor__ProposalThresholdNotMet();
    error Governor__InvalidAmountOfTargets();
    error Governor__ArrayLengthsMismatch();
    error Governor__ProposerHasLiveProposal();
    error Governor__ProposalIdCollision();

    //token
    IGovernanceToken public token;

    uint256 public proposalCount; // total number of proposals, incremented before proposal is created. 0 id is used to check for collisions

    mapping(uint256 proposalId => Proposal) public proposals; // mapping of all proposals

    mapping(address account => uint256 proposalId) public latestProposalIds; // mapping of the latest proposal for each address

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address voter => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal
        bool support;
        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    constructor(address govToken) {
        token = IGovernanceToken(govToken);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {}

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) public returns (uint256 proposalId) {
        // do the checks

        //check if proposer has enough votes
        if (token.getPastVotes(msg.sender, block.number - 1) < proposalThreshold()) {
            revert Governor__ProposalThresholdNotMet();
        }

        // check if there are actions !=0 <-10
        if (targets.length == 0 || targets.length > proposalMaxOperations()) {
            revert Governor__InvalidAmountOfTargets();
        }
        // check if lengtsh mismatch
        if (
            targets.length != values.length || targets.length != signatures.length || targets.length != calldatas.length
        ) {
            revert Governor__ArrayLengthsMismatch();
        }

        // check if proposer has pending of active proposal? stop the spam?
        uint256 latestProposal = latestProposalIds[msg.sender];
        if (latestProposal != 0) {
            ProposalState proposalState = state(latestProposal);
            if (proposalState == ProposalState.Active || proposalState == ProposalState.Pending) {
                revert Governor__ProposerHasLiveProposal();
            }
        }

        proposalCount++;
        proposalId = proposalCount;

        uint256 startBlock = block.number + votingDelay();
        uint256 endBlock = startBlock + votingPeriod();

        Proposal storage newProposal = proposals[proposalId];

        if (newProposal.id != 0) {
            revert Governor__ProposalIdCollision();
        }

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        latestProposalIds[msg.sender] = proposalId;
    }

    function proposalThreshold() public pure returns (uint256) {
        return 1000; // might fail check in tests
    }

    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    }

    function votingDelay() public pure returns (uint256) {
        return 1;
    }

    function votingPeriod() public pure returns (uint256) {
        return 21600; // 3 days in blocks (assuming 12s blocks)
    }
}

interface IGovernanceToken {
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
}
// 3 * 24 * 60 * 60 = 172800 / 12 = 14400
