## About

Initially this project is a DAO on top of my [Uniswap V2 project](https://github.com/mskhno/uniswap-v2-project). This may change in future commits.
A proposal will be a ```createPair``` suggestion. Users will vote on it and then a new pair will be create via ```UniswapV2Factory```, or not.

This is a simple DAO with voting mechanism being a governance token. Owners need to delegate voting power to themselves or other to vote - ERC5805.

All DAO's delays and periods will be based on **block.number** and this clock will be standardized as ERC6372.

The proposal lifecycle will consist of following stages:
   1. After the creation of proposal there is a **voting delay**. It is implemented for users to get ready for voting: increase voting power, unstake tokens etc.
   2. The moment this voting delay has passes, there is a **voting period**.
   3. After voting is finished, the proposal is **queued**. This is done so that user who voted against it can exit the protocol and as an additional safety.
   4. **Execution**. Proposal can be finally executed by users.
   5. // Expired
   6. If proposal is found to be malicious, guardian address can **cancel** the proposal.
   
## Structure

1. ```GovernanceToken```
This is the way the DAO will determine voting powers of users. This will be an ```ERC20``` token with inherited ```ERC20Permit``` extension, and coded ```ERC20Votes```.

Contract will be a standard ERC20 token as an asset, but addition of ERC20Votes will enable tracking voting power via checkpoints.
Tokens map 1:1 to voting power and need to be delegated to be usable in voting.

Checkpoints are going to be created for every delegation, mint, burn and transfer operation. They are created for each delegate's voting power and for the total supply. The way to do it is to override ERC20's _update function. It should first update balances(super._update) and then move voting power. The _transferVotingPower function will do this and also create checkpoints accordingly.

Checkpoint are stored in arrays of Checkpoint struct, which contains two value: block.number of checkpoint and it's voting power value.

Those arrays are updated by pushing new checkpoints.

2. ```Governor```
Logic of creating proposals, different voting functions and execution is going to be handled.

```Governor``` will read from ```GovernanceToken``` to determine voting powers of voters at the time of **voting period**. 

3. ```Timelock```
Emposes a delay on each successful proposal. 

## TODO

Read ERC20Votes code

How Timelock works?
Read blog on DAO or Timelock type code

