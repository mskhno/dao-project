## About

This project is a DAO built on top of OpenZeppelin's ERC20Votes extension. For learning purposes, i decided to code the extension that allows historical tracking of voting units myself. 

## DAO 

The protocol is going of three contracts: ```GovernanceToken.sol```, ```Governor.sol``` and ```Timelock.sol```.

System's voting mechanism is based on ERC20 tokens. The treshold for proposal creation is set at 1000 tokens. For proposal to pass, it needs to have more FOR votes than AGAINST and reach a 30% quorum. 

DAO's periods and delays(the clock) are based on **block.number**. The average block time is considered to be 12 seconds.
*Note: the clock may be changed to block.timestamp. This is going to be reflected as in ERC5808*

Proposal lifecycle consists of the following stages:
   1. After it's created, the **voting delay** has to pass for the actual voting to start. It is set at 2 days.
   2. Delay ends, and the **voting period starts**. It lasts for 3 days.
   3. If the proposal does not pass, it is considered **canceled**. If it does, **timelock** period starts, whish is another 2 days.
   4. After timelock period is finished, the proposal is **executed**.

At any point of proposal before it is executed, **guardian** address can cancel it.

Proposal stages are mapped to the following states:
   1. Review
   2. Active
   3. Queued
   4. Executed
   5. Canceled
   
## Contracts

### ```GovernanceToken.sol```
This contract is the way DAO handles voting. Holders of this ERC20 token can participate in governance of this protocol. Contract inherits from OpenZeppelin's ERC20 and is ERC5808 standardized. 

Tokens map 1:1 to voting units. The contract has checkpointing functionality to track historical voting powers and solve double spending problem. 

Overall, ```GovernanceToken.sol``` determines who can create proposals and participate in voting and determines their voting power.

#### Checkpointing mechanism
To solve double voting problem and figure out the voting powers of users at a certain point in time, checkpointing mechanish is implemented. It uses ERC5805 as framework to derive voting units from tokens without transfering them, and then updates the historical data of an account to track its own voting power.

To express voting power, users need to **delegate**. Power can be delegated to themselves, to a trusted party, or to zero address. This mechanism also allows to save gas for the whole community of DAO. 

Checkpointing mechanism tracks the total supply and addresses voting powers with the help of ```totalSupplyCheckpoints``` and ```delegatePowerCheckpoints``` mappings. Since every user can be a delegatee and voting is done with voting units and not tokens directly, it is possible to track only each delegatee's voting power and not each user's token balance. Voting power is again defined as all voting units delegated to an address at some block number.

Therefore, token operations create checkpoints only for delegatee's of involved parties.

### ```Governor.sol```

This contract is the way for this DAO to handle voting, proposals and their execution. 

```Governor.sol``` reads from ```GovernanceToken.sol``` and assigns voting units to one of **3 options** during voting stage:
   1. FOR
   2. AGAINST
   3. ABSTAIN
   
A passed proposal is the one that has:
   1. More FOR than AGAINST votes
   2. Reached the 30% quorum quota.
   
### ```Timelock.sol```

*This will be described later when i get the idea of the role and the steps involved into "timelocking" a proposal.*