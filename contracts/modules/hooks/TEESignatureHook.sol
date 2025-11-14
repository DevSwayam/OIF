// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// ──────────────────────────────────────────────────────────────────────────────
//     _   __    _  __
//    / | / /__ | |/ /_  _______
//   /  |/ / _ \|   / / / / ___/
//  / /|  /  __/   / /_/ (__  )
// /_/ |_/\___/_/|_\__,_/____/
//
// ──────────────────────────────────────────────────────────────────────────────
// Nexus: A suite of contracts for Modular Smart Accounts compliant with ERC-7579 and ERC-4337, developed by Biconomy.
// Learn more at https://biconomy.io. To report security issues, please contact us at: security@biconomy.io

import { IHook } from "../../interfaces/modules/IHook.sol";
import { MODULE_TYPE_HOOK } from "../../types/Constants.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/// @title TEE Signature Hook
/// @notice A pre-execution hook that requires TEE (Trusted Execution Environment) signatures
///         before allowing any execution on an account
/// @dev This hook verifies that a TEE signature is present for all account executions
///      The TEE signature must be appended to the end of msgData (last 65 bytes)
contract TEESignatureHook is IHook {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The fixed TEE public key address that signs all transactions
    address public immutable teePublicKey;

    /// @notice Mapping to track which accounts have this hook installed
    mapping(address => bool) private installed;

    /// @notice Standard TEE signature length (65 bytes for ECDSA)
    uint256 private constant TEE_SIGNATURE_LENGTH = 65;

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a TEE signature is successfully verified
    event TEESignatureVerified(address indexed account, bytes32 indexed hash);

    /// @notice Event emitted when the hook is installed on an account
    event HookInstalled(address indexed account);

    /// @notice Event emitted when the hook is uninstalled from an account
    event HookUninstalled(address indexed account);

    /*//////////////////////////////////////////////////////////////////////////
                                     ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error ModuleAlreadyInitialized();
    error SignatureTooShort();
    error InvalidTEESignature();

    /*//////////////////////////////////////////////////////////////////////////
                            MODULE LIFECYCLE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Installs the module and registers the TEE public key
    /// @param data ABI-encoded TEE public key address (20 bytes)
    function onInstall(bytes calldata data) external override {
        require(data.length == 20, NoTEEPublicKeyProvided());
        require(!isInitialized(msg.sender), ModuleAlreadyInitialized());

        address teePublicKey = address(bytes20(data));
        require(teePublicKey != address(0), InvalidTEEPublicKey());

        teePublicKeys[msg.sender] = teePublicKey;
        emit TEEPublicKeySet(msg.sender, teePublicKey);
    }

    /// @notice Uninstalls the module and removes the TEE public key
    function onUninstall(bytes calldata) external override {
        delete teePublicKeys[msg.sender];
        emit TEEPublicKeySet(msg.sender, address(0));
    }

    /// @notice Checks if the module matches the HOOK module type
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK;
    }

    /// @notice Checks if the module is initialized for an account
    function isInitialized(address smartAccount) public view returns (bool) {
        return teePublicKeys[smartAccount] != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        HOOK EXECUTION LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Pre-execution check that verifies TEE signature
    /// @dev Expects msgData to have TEE signature appended at the end (last 65 bytes)
    ///      TEE signature is over: keccak256(abi.encodePacked(msgSender, msgValue, actualMsgData))
    /// @param msgSender The original sender of the transaction
    /// @param msgValue The amount of wei sent with the call
    /// @param msgData The calldata with TEE signature appended at the end
    /// @return hookData Empty bytes (not used in postCheck)
    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        address account = msg.sender; // msg.sender is the account calling this hook
        address teePublicKey = teePublicKeys[account];

        require(teePublicKey != address(0), NoTEEPublicKeyRegistered());
        require(msgData.length >= TEE_SIGNATURE_LENGTH, SignatureTooShort());

        // Extract actual execution data (everything except last 65 bytes)
        bytes calldata actualMsgData = msgData[:msgData.length - TEE_SIGNATURE_LENGTH];

        // Extract TEE signature (last 65 bytes)
        bytes calldata teeSignature = msgData[msgData.length - TEE_SIGNATURE_LENGTH:];

        // Compute hash of execution data
        bytes32 executionHash = keccak256(abi.encodePacked(msgSender, msgValue, actualMsgData));

        // Verify TEE signature
        address recoveredSigner = executionHash.recover(teeSignature);
        require(recoveredSigner == teePublicKey, InvalidTEESignature());

        emit TEESignatureVerified(account, executionHash);

        return ""; // No data needed for postCheck
    }

    /// @notice Post-execution check (no-op in this implementation)
    /// @param hookData Data returned from preCheck (unused)
    function postCheck(bytes calldata hookData) external override {
        // No post-execution checks needed
    }

    /*//////////////////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the TEE public key for a specific account
    function getTEEPublicKey(address account) external view returns (address) {
        return teePublicKeys[account];
    }

    /// @notice Updates the TEE public key for the calling account
    function updateTEEPublicKey(address newTEEPublicKey) external {
        require(newTEEPublicKey != address(0), InvalidTEEPublicKey());
        require(isInitialized(msg.sender), NoTEEPublicKeyRegistered());

        teePublicKeys[msg.sender] = newTEEPublicKey;
        emit TEEPublicKeySet(msg.sender, newTEEPublicKey);
    }
}
