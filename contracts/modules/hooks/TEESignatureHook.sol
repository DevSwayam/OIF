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

/// @title ITEEAlive Interface
/// @notice Interface for checking if TEE is alive/online
interface ITEEAlive {
    function getIsAlive() external view returns (bool);
}

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

    /// @notice The fixed TEE signer address (recovered from signature verification)
    address public immutable teeSignerAddress;

    /// @notice The TEEAlive contract to check if TEE is online
    ITEEAlive public immutable teeAliveContract;

    /// @notice Mapping to track which accounts have this hook installed
    mapping(address => bool) private installed;

    /// @notice Standard TEE signature length (65 bytes for ECDSA)
    uint256 private constant TEE_SIGNATURE_LENGTH = 65;

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a TEE signature is successfully verified
    event TEESignatureVerified(address indexed account, bytes32 indexed hash);

    /// @notice Event emitted when TEE verification is bypassed because TEE is offline
    event TEEVerificationBypassed(address indexed account, bytes32 indexed hash);

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
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a new TEE Signature Hook with a fixed TEE signer address and TEEAlive contract
    /// @dev The TEE signer address and TEEAlive contract are immutable and set at deployment
    /// @param _teeAliveContract Address of the TEEAlive contract to check TEE status
    constructor(address _teeAliveContract) {
        teeSignerAddress = 0xAF9fC206261DF20a7f2Be9B379B101FAFd983117;
        teeAliveContract = ITEEAlive(_teeAliveContract);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            MODULE LIFECYCLE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Installs the module on an account
    function onInstall(bytes calldata /* data */) external override {
        require(!isInitialized(msg.sender), ModuleAlreadyInitialized());
        installed[msg.sender] = true;
        emit HookInstalled(msg.sender);
    }

    /// @notice Uninstalls the module from an account
    function onUninstall(bytes calldata) external override {
        installed[msg.sender] = false;
        emit HookUninstalled(msg.sender);
    }

    /// @notice Checks if the module matches the HOOK module type
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK;
    }

    /// @notice Checks if the module is initialized for an account
    function isInitialized(address smartAccount) public view returns (bool) {
        return installed[smartAccount];
    }

    /*//////////////////////////////////////////////////////////////////////////
                        HOOK EXECUTION LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Pre-execution check that verifies TEE signature if TEE is online
    /// @dev If TEE is offline (getIsAlive() returns false), signature verification is bypassed
    ///      If TEE is online, expects msgData to have TEE signature appended at the end (last 65 bytes)
    ///      TEE signature is over: keccak256(abi.encodePacked(msgSender, msgValue, actualMsgData))
    /// @param msgSender The original sender of the transaction
    /// @param msgValue The amount of wei sent with the call
    /// @param msgData The calldata (with optional TEE signature appended if TEE is online)
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

        // Check if TEE is alive/online
        bool teeStatus = teeAliveContract.getIsAlive();

        if (!teeStatus) {
            // TEE is offline - bypass signature verification
            bytes32 bypassHash = keccak256(abi.encodePacked(msgSender, msgValue, msgData));
            emit TEEVerificationBypassed(account, bypassHash);
            return ""; // No TEE verification needed
        }

        // TEE is online - require and verify TEE signature
        require(msgData.length >= TEE_SIGNATURE_LENGTH, SignatureTooShort());

        // Extract actual execution data (everything except last 65 bytes)
        bytes calldata actualMsgData = msgData[:msgData.length - TEE_SIGNATURE_LENGTH];

        // Extract TEE signature (last 65 bytes)
        bytes calldata teeSignature = msgData[msgData.length - TEE_SIGNATURE_LENGTH:];

        // Compute hash of execution data
        bytes32 executionHash = keccak256(abi.encodePacked(msgSender, msgValue, actualMsgData));

        // Verify TEE signature by recovering signer address
        address recoveredSigner = executionHash.recover(teeSignature);
        require(recoveredSigner == teeSignerAddress, InvalidTEESignature());

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

    /// @notice Gets the fixed TEE signer address used by this hook
    /// @return The TEE signer address
    function getTEESignerAddress() external view returns (address) {
        return teeSignerAddress;
    }

    /// @notice Gets the TEEAlive contract address
    /// @return The TEEAlive contract address
    function getTEEAliveContract() external view returns (address) {
        return address(teeAliveContract);
    }

    /// @notice Checks if TEE is currently alive/online
    /// @return True if TEE is online, false otherwise
    function isTEEAlive() external view returns (bool) {
        return teeAliveContract.getIsAlive();
    }
}
