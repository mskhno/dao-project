// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IGovernanceToken} from "src/interfaces/IGovernanceToken.sol";
import {ITimelock} from "src/interfaces/ITimelock.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Governor
 * @dev Governor contract for voting on proposals
 *
 * Simple DAO Governor, basically the same as Compound's GovernorAlpha
 */
contract Governor is EIP712 {
    //////////////
    // ERRORS
    //////////////
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
    error Governor__CallerMustBeGuardian();
    error Governor__ProposalCanNotBeCanceled();
    error Governor__ProposalIsNotQueued();

    //////////////
    // STATE VARIABLES
    //////////////
    IGovernanceToken public immutable i_token;
    ITimelock public immutable i_timelock;

    address public immutable i_guardian;

    //@audit vlad. Не нужно, address "достаётся" при `ECDSA.recover()`
    string public constant BALLOT_TYPEHASH = "Ballot(uint256 proposalId,bool support)"; // include address voter?

    string public constant GOVERNOR_NAME = "Governor";
    string public constant GOVERNOR_VERSION = "1";

    uint256 public proposalCount;

    mapping(uint256 proposalId => Proposal) public proposals;
    mapping(address account => uint256 proposalId) public latestProposalIds;

    //////////////
    // TYPES
    //////////////
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        //@audit vlad. Везде в коде ты переводишь string в bytes когда обрабатываешь
        // Поэтому можно сразу `bytes[]` использовать
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
        mapping(address voter => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
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

    //////////////
    // EVENTS
    //////////////
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
    event ProposalExecuted(uint256 proposalId);
    event ProposalCanceled(uint256 proposalId);

    //////////////
    // FUNCTIONS
    //////////////

    constructor(address _token, address _timelock, address _guardian) EIP712(GOVERNOR_NAME, GOVERNOR_VERSION) {
        i_token = IGovernanceToken(_token);
        i_timelock = ITimelock(_timelock);
        i_guardian = _guardian;
    }

    //////////////
    // EXTERNAL FUNCTIONS
    //////////////

    /**
     * @param targets List of contract addresses to interact with
     * @param values List of values to send to the contracts
     * @param signatures List of function signatures to call
     * @param calldatas List of calldatas to send
     * @return proposalId The ID of the created proposal
     *
     * @notice Propose a new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) external returns (uint256 proposalId) {
        if (i_token.getPastVotes(msg.sender, block.number - 1) < proposalThreshold()) {
            revert Governor__ProposalThresholdNotMet();
        }

        if (targets.length == 0 || targets.length > proposalMaxOperations()) {
            revert Governor__InvalidAmountOfTargets();
        }

        if (
            targets.length != values.length || targets.length != signatures.length || targets.length != calldatas.length
        ) {
            revert Governor__ArrayLengthsMismatch();
        }

        uint256 latestProposal = latestProposalIds[msg.sender];
        //@note норм
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

        //@audit vlad. вроде бы unreacheable
        // potentially unreachable?
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

        //@audit vlad. не важно, всё норм
        // should this be before the proposal is created?
        latestProposalIds[msg.sender] = proposalId;

        emit ProposalCreated(proposalId, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock);
    }

    /**
     * @param proposalId The ID of the proposal to queue after it has succeeded
     *
     * @notice Queue proposal to execute later
     *
     * @dev Transactions are queued in the Timelock contract
     */
    function queue(uint256 proposalId) external {
        if (state(proposalId) != ProposalState.Succeeded) {
            revert Governor__ProposalStatusMustBeSucceeded();
        }

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + i_timelock.delay();

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueTransaction(
                proposal.id, proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta
            );
        }

        proposal.eta = eta;

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @param proposalId The ID of the proposal to execute
     *
     * @notice Execute proposal
     *
     * @dev Transactions are executed by the Timelock contract
     * @dev Values sent to the contracts are sent by the Timelock contract
     */
    //@audit vlad. почему это payable?
    // @comment maks. если в пропоузал есть транзакция с переводом эфира. честно не тестил, интуитивно так подумал
    // @comment сейчас подумал, что даже если так, то высылать эфир будет Timelock, а не Governor
    function execute(uint256 proposalId) external payable {
        if (state(proposalId) != ProposalState.Queued) {
            revert Governor__ProposalIsNotQueued();
        }

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            i_timelock.executeTransaction(
                proposal.id,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @param proposalId The ID of the proposal to cancel
     *
     * @notice Cancel proposal before it is executed
     *
     * @dev Only guardian address can cancel proposals
     */
    function cancel(uint256 proposalId) external {
        if (msg.sender != i_guardian) {
            revert Governor__CallerMustBeGuardian();
        }

        ProposalState proposalState = state(proposalId);
        if (proposalState == ProposalState.Executed || proposalState == ProposalState.Canceled) {
            revert Governor__ProposalCanNotBeCanceled();
        }

        Proposal storage proposal = proposals[proposalId];
        proposal.canceled = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            i_timelock.cancelTransaction(
                proposal.id,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @param proposalId The ID of the proposal to cast a vote on
     * @param support Whether to support the proposal or not
     *
     * @notice Vote for or against a proposal
     */
    function castVote(uint256 proposalId, bool support) external {
        _castVote(msg.sender, proposalId, support);
    }

    /**
     * @param proposalId The ID of the proposal to cast a vote on
     * @param support Whether to support the proposal or not
     * @param v Signature component v
     * @param r Signature component r
     * @param s Signature component s
     *
     * @notice Vote for or against a proposal with a signature
     *
     * @dev Maybe add address voter to Ballot struct and check if signer == voter
     */
    function castVoteBySig(uint256 proposalId, bool support, uint8 v, bytes32 r, bytes32 s) external {
        //@audit vlad. Не, шанс коллизии слишком маленький. Из-за парадокса дней рождений шанс 1 коллизии 50% за 2^80 попыток
        // По фану можешь посмотреть с какой скоростью твой ноут печатает числа в цикле
        // При этом коллизия любых адресов, а делегаты 1 токена это супер мало адресов. Потом скину дискуссию по этому поводу (сейчас инета нету)

        // @comment maks. когда пишу код с подписями, моё натуральное желание это впихнуть в подпись как можно больше вещей.
        // тут я подумал об этом, но не смог сузить вот так границу как ты.

        // any checks at all? can it cast a random persons vote in case of random signature spam? sounds like i am not really understading something, missing out
        // возможно ли в теории наспамить в эту функицю кучу подписей, с идеей что хоть одна попадется,
        // в который я угадаю параметры proposalId и support и при этом signer это участник DAO и он делегировал токены,
        // чтобы его голос засчитался? трудно наверно но мозг мой вот так подумал
        // add address voter to the signature and the check signer == voter?
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(digest, v, r, s);

        _castVote(signer, proposalId, support);
    }

    //////////////
    // EXTERNAL VIEW FUNCTIONS
    //////////////

    /**
     * @param proposalId The ID of the proposal to get the actions of
     *
     * @return targets Contract addresses of proposal's transactions
     * @return values Values to send to the contracts
     * @return signatures Function signatures to call
     * @return calldatas Calldatas to send
     */
    function getActions(uint256 proposalId)
        external
        view
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory)
    {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert Governor__InvalidProposalId();
        }

        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.signatures, proposal.calldatas);
    }

    /**
     * @param proposalId The ID of the proposal to get the receipt of
     * @param voter The address of the voter to get the receipt of
     *
     * @return receipt The receipt of the voter
     *
     * @notice Get the receipt of a voter from a proposal
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    //////////////
    // INTERNAL FUNCTIONS
    //////////////

    /**
     * @param proposalId The ID of the proposal to queue
     * @param target The contract address to interact with
     * @param value The value to send to the contract
     * @param signature The function signature to call
     * @param data The calldata to send
     * @param eta The timestamp to execute the transaction
     *
     * @dev Queue single transaction in the Timelock contract
     *
     */
    //@note норм
    function _queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(proposalId, target, value, signature, data, eta));

        //@audit vlad. С комментарием согласен
        // Также хочу заметить, что в нынешнем дизайне proposal не сможет содержать 2 одинаковых действия
        // То есть у них будут одинаковые параметры и одинаковый хэш. Вроде бы у Compaund это свойство есть тоже

        // @comment maks. то, что нельзя вручную в очередь поставить транзакцию это да, поэтому тут чек отлетает
        // "что в нынешнем дизайне proposal не сможет содержать 2 одинаковых действия" - не думал так об этом.
        // по сути строка 393 одинаковый бы txHash посчитала, но тогда как раз нужен этот чек?
        // вижу тут это так - ситуация если этот чек убрать. queue() в своем for цикле поставит в очередь 2 транзакции,
        // но по итогу в mappinge queuedTransactions будет только одна. при execution пропоузала execute() вызовет executeTransaction() на эти две одинаковые,
        // и по идее Timelock ревертнет на линии 103, так как транзакция уже не в очереди, а txHash у второй такой транзакции такой же как у первой
        // по сути наебнется весь пропоузал?

        // may be unnecessary check, because there is no way to manually queue a transaction in the timelock contract
        // as a check for collision, it's really unlikely since txHash includes proposalId and proposal.eta
        if (i_timelock.queuedTransactions(txHash)) {
            revert Governor__TransactionIsAlreadyQueued();
        }

        i_timelock.queueTransaction(proposalId, target, value, signature, data, eta);
    }

    /**
     * @param voter The address of the voter to cast a vote
     * @param proposalId The ID of the proposal to cast a vote on
     * @param support Whether to support the proposal or not
     *
     * @dev Cast a vote on a proposal
     */
    //@note норм
    function _castVote(address voter, uint256 proposalId, bool support) internal {
        if (state(proposalId) != ProposalState.Active) {
            revert Governor__ProposalIsNotActive();
        }

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];

        if (receipt.hasVoted) {
            revert Governor__AddressAlreadyVoted();
        }

        uint256 votes = i_token.getPastVotes(voter, proposal.startBlock - 1);

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

    /**
     * @param proposalId The ID of the proposal to check
     *
     * @return bool Whether the proposal meets the quorum
     *
     * @dev Check if the proposal meets the quorum
     */
    //@note норм
    function _checkProposalMeetsQuorum(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        //@audit vlad. Precision loss не будет, ну или он слишком малый
        // @comment maks. мало у меня уверенности в solidity math
        uint256 quorumAmount = (i_token.getPastTotalSupply(proposal.startBlock - 1)) * quorumVotes() / 100; // precision loss?

        if (proposal.forVotes + proposal.againstVotes >= quorumAmount) {
            return true;
        }

        return false;
    }

    //////////////
    // GETTERS
    //////////////

    /**
     * @param proposalId The ID of the proposal to get the state of
     *
     * @return proposalState The state of the proposal
     *
     * @notice Get the state of a proposal
     */
    //@note вроде норм, надеюсь ты с логикой здесь разобрался
    function state(uint256 proposalId) public view returns (ProposalState proposalState) {
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
        } else if (block.timestamp >= proposal.eta + i_timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @return uint256 The threshold of votes needed to propose
     */
    //@audit vlad. Не учитывает что токен имеет 18 decimals, считай proposalThreshold и нету
    // @comment maks. так же не уверен в использовании decimals
    function proposalThreshold() public pure returns (uint256) {
        return 1000;
    }

    /**
     * @return uint256 The maximum amount of operations in a proposal
     */
    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    }

    /**
     * @return uint256 The delay in blocks before a proposal can be executed
     *
     * @dev 2 days in blocks, assuming 12s blocks
     */
    function votingDelay() public pure returns (uint256) {
        return 14400;
    }

    /**
     * @return uint256 The period in blocks where votes can be cast
     *
     * @dev 3 days in blocks, assuming 12s blocks
     */
    function votingPeriod() public pure returns (uint256) {
        return 21600;
    }

    /**
     * @return uint256 The percentage of total supply needed for quorum
     */
    function quorumVotes() public pure returns (uint256) {
        return 30;
    }
}
