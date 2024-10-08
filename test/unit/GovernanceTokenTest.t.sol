// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "src/GovernanceToken.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;

    bytes32 tokenDomainSeparator;
    bytes32 private constant EIP712_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    string name = "GovernanceToken";
    string symbol = "GT";
    string version = "1";

    address owner;
    uint256 ownerKey;

    address spender = makeAddr("spender");

    function setUp() public {
        token = new GovernanceToken(name, symbol, version);

        // build eip712 domain separator
        string memory eip712Name = token.EIP712Name(); // name()
        string memory eip712Version = token.EIP712Version();
        tokenDomainSeparator = keccak256(
            abi.encode(
                EIP712_TYPE_HASH,
                keccak256(bytes(eip712Name)),
                keccak256(bytes(eip712Version)),
                block.chainid,
                address(token)
            )
        );

        (owner, ownerKey) = makeAddrAndKey("owner");
    }

    ////////////
    /// permit
    ////////////

    function test_permit_revertsWhenSignatureIsExpired() public {
        uint256 value = 1000e18;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp;

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(tokenDomainSeparator, structHash);

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(ownerKey, digest);

        vm.warp(deadline + 1000);
        vm.expectRevert(GovernanceToken.GovernanceToken_SignatureExpired.selector);
        token.permit(owner, spender, value, nonce, deadline, v, r, s);
    }

    function test_permit_revertsWhenNonceIsInvalid() public {
        uint256 value = 1000e18;
        uint256 nonce = token.nonces(owner) + 1;
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(tokenDomainSeparator, structHash);

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(ownerKey, digest);

        vm.expectRevert(GovernanceToken.GovernanceToken_InvalidNonce.selector);
        token.permit(owner, spender, value, nonce, deadline, v, r, s);
    }

    function test_permit_revertsWhenSignatureIsInvalid() public {
        address badOwner = makeAddr("badOwner");
        uint256 value = 1000e18;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, badOwner, spender, value, nonce, deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(tokenDomainSeparator, structHash);

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(ownerKey, digest);

        vm.expectRevert(GovernanceToken.GovernanceToken_InvalidSignature.selector);
        token.permit(owner, spender, value, nonce, deadline, v, r, s);
    }

    function test_permit_approvesSpender() public {
        uint256 value = 1000e18;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = MessageHashUtils.toTypedDataHash(tokenDomainSeparator, structHash);

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(ownerKey, digest);

        uint256 initialApprovall = token.allowance(owner, spender);

        token.permit(owner, spender, value, nonce, deadline, v, r, s);

        uint256 finalApprovall = token.allowance(owner, spender);

        assertEq(finalApprovall - initialApprovall, value);
    }

    ////////////
    /// EIP6372
    ////////////

    function test_clock_returnsBlockNumber() public {
        assertEq(token.clock(), SafeCast.toUint48(block.number));

        vm.roll(block.number + 100);

        assertEq(token.clock(), SafeCast.toUint48(block.number));
    }

    function Test_CLOCK_MODE_returnsRightClockMode() public view {
        string memory expectedMode = "mode=blocknumber&from=default";
        string memory actualMode = token.CLOCK_MODE();
        assertEq(keccak256(bytes(expectedMode)), keccak256(bytes(actualMode)));
    }
}
