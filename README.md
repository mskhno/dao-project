## About

This project initially serves as a DAO built on top of my [Uniswap V2 project](https://github.com/mskhno/uniswap-v2-project), though it may evolve in future updates. The DAO enables users to propose new pairs via `createPair`, and after a vote, the pair is either created through `UniswapV2Factory` or rejected.

Governance is token-based, with 1:1 mapping of tokens to voting units. Holders must delegate their voting power to themselves or others to participate. All delays and periods are based on **block.number**.

The proposal lifecycle follows these stages:
1. **Voting Delay:** After a proposal is created, there is a delay to allow users time to prepare (e.g., increasing voting power or unstaking tokens).
2. **Voting Period:** Once the delay passes, voting begins.
3. **Queuing:** After voting, the proposal is queued, providing time for dissenting users to exit and serving as an additional safety measure.
4. **Execution:** If passed, users can execute the proposal.
5. **Expiration:** Proposals that expire can no longer be executed.
6. **Cancellation:** A proposal can be canceled by a guardian address if deemed malicious.

## Structure

1. **`GovernanceToken`**:  
   This ERC20 token governs voting power within the DAO, with voting rights delegated to users and stored via checkpoints. The contract implements the ERC5805 standard for voting delegation and clock standardization. Each token represents 1 voting unit, but power must be delegated to be used, therefore the total amount of voting units in the system can be less than total token supply.

   Checkpoints are created for each delegatee during minting, burning, or transfers. The `ERC20` `_update` function is overridden to manage both token balances and voting power via `_transferVotingUnits`. This function handles the creation of checkpoints and updates them whenever voting power changes, such as when tokens are delegated, minted, or burned.

   Key points:
   - ERC20 token with ERC20Permit for permits.
   - ERC5805 standard for delegation and internal clock management.
   - Checkpoint mechanism tracks voting power over time.

2. **`Governor`**:  
   Handles the logic for proposal creation, voting, and execution. It reads from the `GovernanceToken` contract to determine voter power at the start of each voting period.

3. **`Timelock`**:  
   Imposes a delay on executing successful proposals to provide a buffer for any necessary actions, such as users exiting the protocol.