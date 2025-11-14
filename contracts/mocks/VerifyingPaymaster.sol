// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { BasePaymaster } from "account-abstraction/core/BasePaymaster.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @title VerifyingPaymaster
 * @dev A simple paymaster that verifies signatures for sponsoring transactions
 * This is a minimal implementation for testing purposes
 */
contract VerifyingPaymaster is BasePaymaster {
    using ECDSA for bytes32;

    address public immutable verifyingSigner;

    constructor(IEntryPoint _entryPoint, address _verifyingSigner) BasePaymaster(_entryPoint, _verifyingSigner) {
        verifyingSigner = _verifyingSigner;
    }

    function getHash(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(userOp.sender, userOp.nonce, validUntil, validAfter));
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 /* maxCost */
    ) internal view override returns (bytes memory context, uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        bytes calldata paymasterAndData = userOp.paymasterAndData;

        // paymasterAndData format: paymaster address (20 bytes) | signature (65 bytes)
        require(paymasterAndData.length >= 85, "VerifyingPaymaster: invalid signature length");

        bytes calldata signature = paymasterAndData[20:];
        address recovered = hash.recover(signature);

        // Validate signer
        if (recovered != verifyingSigner) {
            return ("", 1); // Invalid signature
        }

        return ("", 0); // Valid
    }
}
