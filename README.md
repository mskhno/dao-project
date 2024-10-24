# Simple DAO with ERC20 Voting Mechanism

This project demonstrates a basic implementation of a Decentralized Autonomous Organization (DAO) using an ERC20 token for voting. `ERC20Votes` extension is used to track voting power.

## Features

1. **ERC20 Token Voting**: Token holders can vote on proposals or delegate their voting power.
2. **Proposal Creation**: A minimum of 1000 tokens is required to create a proposal.
3.  **Voting Options**: Users can vote:
      - **For**: In favor of the proposal.
      - **Against**: Opposing the proposal.
      - **Abstain**: Neither for nor against the proposal.
4. **Proposal Passing Criteria**: 
     - A proposal must have more **For** votes than **Against**.
     - A quorum of 30% of the total token supply must be reached for the vote to be valid.

## Protocol Structure

1. **`GovernanceToken.sol`**: Defines the ERC20 token used for governance, managing transfers, minting, and voting power via `ERC20Votes`.
  
2. **`Governor.sol`**: Handles the core governance logic, including:
     - Proposal creation
     - Voting
     - Proposal execution after the timelock period

3. **`Timelock.sol`**: Enforces a delay period after a proposal passes before it can be executed, ensuring time for review or challenge.

## Proposal Lifecycle

1. **Voting Delay**: A 2-day delay after proposal creation before voting begins.
2. **Voting Period**: A 3-day period where users can vote.
3. **Outcome**:
   - If the proposal fails, it is considered **canceled**.
   - If passed, a 2-day **timelock** period follows before the proposal can be executed.
4. **Execution**: After the timelock, the proposal is executed.

At any point before execution, a **guardian** address can cancel the proposal.
