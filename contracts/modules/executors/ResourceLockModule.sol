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

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IExecutor } from "../../interfaces/modules/IExecutor.sol";
import { MODULE_TYPE_EXECUTOR } from "../../types/Constants.sol";
import { IERC7579Account } from "../../interfaces/IERC7579Account.sol";
import { ExecutionMode, ExecType, CallType, CALLTYPE_SINGLE, EXECTYPE_DEFAULT } from "../../lib/ModeLib.sol";
import { ExecLib } from "../../lib/ExecLib.sol";

/// @title ITEEAlive Interface
/// @notice Interface for checking if TEE is alive/online
interface ITEEAlive {
    function getIsAlive() external view returns (bool);
}

/// @title MandateOutput struct
/// @notice Output description for cross-chain settlements
struct MandateOutput {
    bytes32 oracle;
    bytes32 settler;
    uint256 chainId;
    bytes32 token;
    uint256 amount;
    bytes32 recipient;
    bytes callbackData;
    bytes context;
}

/// @title StandardOrder struct
/// @notice Order structure for settlements
struct StandardOrder {
    address user;
    uint256 nonce;
    uint256 originChainId;
    uint32 expires;
    uint32 fillDeadline;
    address inputOracle;
    uint256[2][] inputs;
    MandateOutput[] outputs;
}

/// @title SolveParams struct
/// @notice Parameters for solve execution
struct SolveParams {
    uint32 timestamp;
    bytes32 solver;
}

/// @title IInputSettler Interface
/// @notice Interface for the inputSettler contract that handles settlement finalization
interface IInputSettler {
    /// @notice Finalises an order when called directly by the solver
    /// @param order StandardOrder signed in conjunction with a Compact to form an order
    /// @param signatures A signature for the sponsor and the allocator
    /// @param solveParams List of solve parameters for when the outputs were filled
    /// @param destination Where to send the inputs
    /// @param call Optional callback data
    function finalise(
        StandardOrder calldata order,
        bytes calldata signatures,
        SolveParams[] calldata solveParams,
        bytes32 destination,
        bytes calldata call
    ) external;
}

/// @title ResourceLockModule
/// @notice ERC-7579 compliant Executor module for executing intent settlements with TEE authorization
/// @dev This module acts as a bridge between solvers and Nexus accounts
///      TEE signature verification is handled by TEESignatureHook during executeFromExecutor
///      This module executes token approvals and triggers inputSettler finalization
///      Inspired by ERC-7683 settlers and Open Intent Framework
contract ResourceLockModule is IExecutor {

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The TEEAlive contract to check if TEE is online
    ITEEAlive public immutable teeAliveContract;

    /// @notice Mapping to track which accounts have this module installed
    mapping(address => bool) private installed;

    /// @notice Track nonces per account for replay protection
    mapping(address => uint256) public accountNonces;

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a settlement is executed
    event SettlementExecuted(
        address indexed account,
        address indexed solver,
        address indexed token,
        uint256 amount,
        address inputSettler
    );

    /// @notice Emitted when module is installed on an account
    event ModuleInstalled(address indexed account);

    /// @notice Emitted when module is uninstalled from an account
    event ModuleUninstalled(address indexed account);

    /*//////////////////////////////////////////////////////////////////////////
                                     ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error ModuleAlreadyInitialized();
    error ModuleNotInitialized();
    error InvalidToken();
    error InvalidAmount();
    error InvalidNonce();
    error InvalidSettler();
    error ApprovalFailed();
    error FinalizeFailed();
    error TEEOffline();

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a new Resource Lock Module with TEEAlive contract
    /// @param _teeAliveContract Address of the TEEAlive contract to check TEE status
    constructor(address _teeAliveContract) {
        teeAliveContract = ITEEAlive(_teeAliveContract);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            MODULE LIFECYCLE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Installs the module on an account
    /// @dev Called by the Nexus account when installing the module
    function onInstall(bytes calldata /* data */) external override {
        require(!isInitialized(msg.sender), ModuleAlreadyInitialized());
        installed[msg.sender] = true;
        emit ModuleInstalled(msg.sender);
    }

    /// @notice Uninstalls the module from an account
    /// @dev Called by the Nexus account when uninstalling the module
    function onUninstall(bytes calldata /* data */) external override {
        installed[msg.sender] = false;
        emit ModuleUninstalled(msg.sender);
    }

    /// @notice Checks if the module matches the EXECUTOR module type
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    /// @notice Checks if the module is initialized for an account
    function isInitialized(address smartAccount) public view returns (bool) {
        return installed[smartAccount];
    }

    /*//////////////////////////////////////////////////////////////////////////
                        SETTLEMENT EXECUTION
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Execute an intent settlement with TEE authorization
    /// @dev This function:
    ///      1. Validates settlement parameters
    ///      2. Executes token approval to inputSettler (via executeFromExecutor with TEE signature)
    ///      3. Calls finalize() on inputSettler to complete settlement
    ///      Note: TEE signature is verified by the TEESignatureHook during executeFromExecutor
    /// @param account The Nexus account to execute from
    /// @param token The token address to approve and transfer
    /// @param amount The amount to approve
    /// @param inputSettler The inputSettler contract address
    /// @param settlerData Arbitrary data to pass to inputSettler.finalize()
    /// @param nonce Nonce for replay protection
    /// @param teeSignature TEE signature appended to executeFromExecutor call (validated by hook)
    function executeSettlement(
        address account,
        address token,
        uint256 amount,
        address inputSettler,
        bytes calldata settlerData,
        uint256 nonce,
        bytes calldata teeSignature
    ) external {
        // Basic validation
        require(amount > 0, InvalidAmount());
        require(token != address(0), InvalidToken());
        require(inputSettler != address(0), InvalidSettler());
        require(teeAliveContract.getIsAlive(), TEEOffline());
        require(isInitialized(account), ModuleNotInitialized());
        require(nonce == accountNonces[account], InvalidNonce());

        // Increment nonce
        accountNonces[account]++;

        // Step 1: Execute approval via Nexus account (hook will verify TEE signature)
        _executeApproval(account, token, amount, inputSettler, teeSignature);

        emit SettlementExecuted(account, msg.sender, token, amount, inputSettler);
    }

    /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Execute token approval on behalf of the Nexus account
    /// @dev Uses executeFromExecutor to call token.approve(inputSettler, amount)
    ///      Appends TEE signature to the call so the hook can validate it via withHook modifier
    ///      The TEE signature must be appended because withHook modifier passes msg.data to hook's preCheck
    /// @param account The Nexus account
    /// @param token The token to approve
    /// @param amount The amount to approve
    /// @param inputSettler The spender (inputSettler contract)
    /// @param teeSignature The TEE signature to append (validated by hook's preCheck via msg.data)
    function _executeApproval(
        address account,
        address token,
        uint256 amount,
        address inputSettler,
        bytes calldata teeSignature
    ) private {
        IERC7579Account nexusAccount = IERC7579Account(account);

        // Create approval calldata: token.approve(inputSettler, amount)
        bytes memory approveCallData = abi.encodeWithSelector(
            IERC20.approve.selector,
            inputSettler,
            amount
        );

        // Encode execution using ExecLib
        bytes memory execution = ExecLib.encodeSingle(token, 0, approveCallData);

        // Create execution mode for single call
        ExecutionMode mode = _encodeExecutionMode(CALLTYPE_SINGLE, EXECTYPE_DEFAULT);

        // Encode the executeFromExecutor call using abi.encodeCall with interface
        bytes memory callData = abi.encodeCall(
            nexusAccount.executeFromExecutor,
            (mode, execution)
        );

        // Append TEE signature to the end of calldata
        // This ensures msg.data in withHook modifier contains: [executeFromExecutor_calldata][teeSignature_65bytes]
        bytes memory callDataWithSignature = abi.encodePacked(callData, teeSignature);

        // Execute with low-level call to preserve the full calldata in msg.data for hook validation
        (bool success, bytes memory returnData) = account.call(callDataWithSignature);
        require(success, ApprovalFailed());

        // Decode and validate return data
        if (returnData.length > 0) {
            bytes[] memory result = abi.decode(returnData, (bytes[]));
            require(result.length > 0, ApprovalFailed());
        }
    }


    /// @notice Encode execution mode for Nexus account
    /// @param callType The call type (single, batch, delegate)
    /// @param execType The execution type (default, try)
    /// @return mode The encoded execution mode
    function _encodeExecutionMode(
        CallType callType,
        ExecType execType
    ) private pure returns (ExecutionMode mode) {
        return ExecutionMode.wrap(
            bytes32(abi.encodePacked(callType, execType, bytes4(0x00000000), bytes22(0)))
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Get the current nonce for an account
    /// @param account The account to check
    /// @return The current nonce
    function getNonce(address account) external view returns (uint256) {
        return accountNonces[account];
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
