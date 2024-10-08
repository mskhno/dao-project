// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

using SafeCast for uint256;

/**
 * @title GovernanceToken
 * @author Max Sakhno
 * @notice This contract is an example of a ERC20 governance token. It is basically ERC20Votes extension
 * that was coded manually for the purpose of learning.
 *
 * @dev Built on top of EIP712 and Nonces contracts from OpenZeppelin Contracts v5.0.2 library.
 * @dev Uses EIP5805
 * @dev Added permit funcitonality
 *
 */

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
contract GovernanceToken is ERC20, EIP712, Nonces {
    ////////////
    /// ERRORS
    ////////////
    error GovernanceToken_SignatureExpired();
    error GovernanceToken_InvalidNonce();
    error GovernanceToken_InvalidSignature();

    ////////////
    /// STATE VARIABLES
    ////////////

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    ////////////
    /// FUCNTIONS
    ////////////

    constructor(string memory name, string memory symbol, string memory version)
        ERC20(name, symbol)
        EIP712(name, version)
    {}

    ////////////
    /// EXTERNAL FUNCTIONS
    ////////////

    /**
     * @notice Approve token transfer with signature
     * @param owner Owner of tokens to be approved, anticipated signer of the signature
     * @param spender The address which will be approved
     * @param value The amount of tokens to be approved
     * @param nonce The next unused nonce of the owner
     * @param deadline The time after which the signature is invalid
     *
     * @dev Signature expiries AT deadline, not after
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // check deadline
        if (block.timestamp > deadline) {
            // should use block.timestamp?
            revert GovernanceToken_SignatureExpired();
        }

        // check nonce
        if (nonce != nonces(owner)) {
            revert GovernanceToken_InvalidNonce();
        }

        // create struct hash
        bytes32 message = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));
        bytes32 digest = _hashTypedDataV4(message);

        // check signer
        address signer = ECDSA.recover(digest, v, r, s);
        if (signer != owner) {
            revert GovernanceToken_InvalidSignature();
        }
        // approve
        _approve(owner, spender, value);
    }

    // imlement EIP5805

    // eip 6372
    function clock() public view returns (uint48) {
        return block.number.toUint48();
    }

    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    // delegation part

    // implement checkpointing
    // override _update to add checkpointing

    ////////////
    /// GETTERS
    ////////////
    function EIP712Name() public view returns (string memory) {
        return _EIP712Name();
    }

    function EIP712Version() public view returns (string memory) {
        return _EIP712Version();
    }
}
