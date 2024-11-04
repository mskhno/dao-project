# Simple DAO with ERC20 Voting Mechanism

This project showcases a basic implementation of a Decentralized Autonomous Organization (DAO) using an ERC20 token as a voting mechanism. The `ERC20Votes` extension is used to track and manage voting power.

## Key Features

- **Governance through ERC20 Tokens**: Token holders can participate in governance by voting directly or delegating their voting power to others.
- **Proposal Creation**: A minimum of 1,000 tokens is required to submit a proposal.
- **Voting Options**:
  - **For**: Support the proposal.
  - **Against**: Oppose the proposal.
- **Proposal Approval Criteria**:
  - A proposal must have more **For** votes than **Against** to pass.
  - A quorum of 30% of the total token supply is required for a proposal to succeed.

## Protocol Structure

- **`GovernanceToken.sol`**: Implements the ERC20 token used as the governance token, with support for voting power management via the `ERC20Votes` extension.
- **`Governor.sol`**: Contains the core governance logic, handling:
  - Creation of proposals
  - Voting processes
  - Managing proposal stages, including queuing and execution.
- **`Timelock.sol`**: Enforces a delay period after a proposal passes before it can be executed, ensuring a review window and safeguarding the protocol.

## Proposal Lifecycle

1. **Voting Delay**: A proposal undergoes a 2-day delay period before voting can commence.
2. **Voting Period**: A 3-day window during which users can cast their votes.
3. **Outcome Determination**:
   - If the proposal fails to meet the required criteria, it is marked as **defeated**.
   - If successful, a 2-day **timelock** period follows, providing time for review before execution.
4. **Execution**: Upon completion of the timelock, the proposal can be executed. Proposals that are not executed within 14 days will **expire**.

A designated **guardian** address has the authority to **cancel** a proposal at any stage before execution.
