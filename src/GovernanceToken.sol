// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovernanceToken
 * @author Max Sakhno
 * @notice This contract is an example of a ERC20 governance token. It is basically ERC20Votes extension
 * that was coded manually for the purpose of learning.
 *
 * @dev Built on top of EIP712 and Nonces contracts from OpenZeppelin Contracts v5.0.2 library.
 * @dev Uses EIP5805
 * @dev Added permit funcitonality
 */
contract GovernanceToken is ERC20, EIP712, Nonces {
    constructor(string memory name, string memory symbol, string memory version)
        ERC20(name, symbol)
        EIP712(name, version)
    {}

    // imlement EIP5805
    // imlement permit function
    // implement checkpointing
    // override _update to add checkpointing
}
