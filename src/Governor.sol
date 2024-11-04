// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IGovernanceToken} from "src/interfaces/IGovernanceToken.sol";
import {ITimelock} from "src/interfaces/ITimelock.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Governor is EIP712 {
    error Governor__ProposalThresholdNotMet();
    error Governor__InvalidAmountOfTargets();
    error Governor__ArrayLengthsMismatch();
    error Governor__ProposerHasLiveProposal();
    error Governor__ProposalIdCollision();
    error Governor__InvalidProposalId();
    error Governor__ProposalIsNotActive();
    error Governor__AddressAlreadyVoted();
    error Governor__ProposalStatusMustBeSucceeded();
    error Governor__TransactionIsAlreadyQueued();

    //token
    IGovernanceToken public token;

    //timelock
    ITimelock public timelock;

    string public constant GOVERNOR_NAME = "Governor";
    string public constant GOVERNOR_VERSION = "1";

    string public constant BALLOT_TYPEHASH = "Ballot(uint256 proposalId,bool support)";

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
        uint256 votes;
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

    event ProposalQueued(uint256 proposalId, uint256 eta);

    constructor(address _token, address _timelock) EIP712(GOVERNOR_NAME, GOVERNOR_VERSION) {
        token = IGovernanceToken(_token);
        timelock = ITimelock(_timelock);
    }

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

        emit ProposalCreated(proposalId, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock);
    }

    // queue

    function queue(uint256 proposalId) public {
        // check state
        if (state(proposalId) != ProposalState.Succeeded) {
            revert Governor__ProposalStatusMustBeSucceeded();
        }

        // queue
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueTransaction(
                proposal.id, proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta
            );
        }
        proposal.eta = eta;

        // emit event
        emit ProposalQueued(proposalId, eta);
    }

    // proposalId is debatable
    function _queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        if (timelock.queuedTransactions(txHash)) {
            // can it happen? maybe if someone queues the transaction manually but no option like this in the system
            // could happen in Compound maybe because txHash is made from tx data and proposal.eta, proposal.id is not included. prob really unlikely
            revert Governor__TransactionIsAlreadyQueued();
        }

        timelock.queueTransaction(proposalId, target, value, signature, data, eta);
    }

    function state(uint256 proposalId) public view returns (ProposalState proposalState) {
        // check proposal id to be >0 and <= proposalCount
        if (proposalId == 0 || proposalId > proposalCount) {
            revert Governor__InvalidProposalId();
        }

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.startBlock > block.number) {
            return ProposalState.Pending;
        } else if (proposal.endBlock > block.number) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || !_checkProposalMeetsQuorum(proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function _checkProposalMeetsQuorum(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 quorumAmount = (token.getPastTotalSupply(proposal.startBlock - 1)) * quorumVotes() / 100; // precision loss?

        if (proposal.forVotes + proposal.againstVotes >= quorumAmount) {
            return true;
        }

        return false;
    }

    // voting
    function castVote(uint256 proposalId, bool support) public {
        _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(uint256 proposalId, bool support, uint8 v, bytes32 r, bytes32 s) public {
        // any checks at all? can it cast a random persons vote in case of random signature spam? sounds like i am not really understading something, missing out
        // возможно ли в теории наспамить в эту функицю кучу подписей, с идеей что хоть одна попадется, в который я угадаю параметры proposalId и support и при этом signer это участник DAO и он делегировал токены, чтобы его голос засчитался? трудно наверно но мозг мой вот так подумал
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(digest, v, r, s);

        _castVote(signer, proposalId, support);
    }

    function _castVote(address voter, uint256 proposalId, bool support) internal {
        // check if its active proposal
        if (state(proposalId) != ProposalState.Active) {
            revert Governor__ProposalIsNotActive();
        }

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];

        // check if they voted
        if (receipt.hasVoted) {
            revert Governor__AddressAlreadyVoted();
        }

        uint256 votes = token.getPastVotes(voter, proposal.startBlock - 1); // voting starts AT startBlock, votes should be delegated before

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCasted(voter, proposalId, support, votes);
    }

    function getActions(uint256 proposalId)
        public
        view
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory)
    {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert Governor__InvalidProposalId();
        }

        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.signatures, proposal.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
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

    function quorumVotes() public pure returns (uint256) {
        return 30; // 30% of total supply
    }
}
