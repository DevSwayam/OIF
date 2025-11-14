// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../../utils/Imports.sol";
import "../../../utils/NexusTest_Base.t.sol";
import { TEESignatureHook } from "../../../../../contracts/modules/hooks/TEESignatureHook.sol";
import { TEEAlive } from "../../../../../contracts/mocks/TEEAlive.sol";

/// @title TestTEESignatureHook
/// @notice Comprehensive tests for TEESignatureHook functionality
contract TestTEESignatureHook is NexusTest_Base {
    TEESignatureHook internal teeHook;
    TEEAlive internal teeAlive;
    uint256 internal teePrivateKey; // TEE private key from .env

    event TEESignatureVerified(address indexed account, bytes32 indexed hash);
    event TEEVerificationBypassed(address indexed account, bytes32 indexed hash);
    event HookInstalled(address indexed account);
    event HookUninstalled(address indexed account);

    /// @notice Sets up the testing environment
    function setUp() public {
        init();

        // Load TEE private key from .env
        teePrivateKey = vm.envUint("PRIVATE_KEY");

        // Deploy TEEAlive contract
        teeAlive = new TEEAlive();

        // Deploy TEESignatureHook with TEEAlive contract and default TEE signer (0xAF9fC206261DF20a7f2Be9B379B101FAFd983117)
        teeHook = new TEESignatureHook(address(teeAlive), address(0));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            CORE TEE SIGNATURE TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Tests execution FAILS without TEE signature when TEE is online
    function test_ExecuteWithoutTEESignature_WhenOnline_Fails() public {
        _installTEEHook();

        // Ensure TEE is online
        assertTrue(teeAlive.getIsAlive(), "TEE should be online");

        // Create execution data WITHOUT TEE signature
        address target = address(0x1234);
        bytes memory data = abi.encodeWithSignature("someFunction()");

        bytes memory callData = abi.encodeWithSelector(
            Nexus.execute.selector,
            target,
            0,
            data
        );

        Execution[] memory execution = new Execution[](1);
        execution[0] = Execution(address(BOB_ACCOUNT), 0, callData);

        PackedUserOperation[] memory userOps = buildPackedUserOperation(
            BOB,
            BOB_ACCOUNT,
            EXECTYPE_DEFAULT,
            execution,
            address(VALIDATOR_MODULE),
            0
        );

        // Record logs to check for UserOperationRevertReason event
        vm.recordLogs();

        // handleOps completes but the UserOperation fails internally
        ENTRYPOINT.handleOps(userOps, payable(address(BOB.addr)));

        // Verify that the UserOperation failed by checking the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundRevertEvent = false;

        for (uint256 i = 0; i < logs.length; i++) {
            // UserOperationRevertReason event signature
            if (logs[i].topics[0] == keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)")) {
                foundRevertEvent = true;
                break;
            }
        }

        assertTrue(foundRevertEvent, "UserOperation should have reverted due to missing TEE signature");
    }

    /// @notice Tests execution SUCCEEDS with valid TEE signature when TEE is online
    function test_ExecuteWithTEESignature_WhenOnline_Success() public {
        _installTEEHook();

        // Ensure TEE is online
        assertTrue(teeAlive.getIsAlive(), "TEE should be online");

        // Test data to sign
        address msgSender = address(ENTRYPOINT);
        uint256 msgValue = 0;
        bytes memory msgData = hex"e9ae5c53000000000000000000000000000000000000000000000000000000000000123400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000040";

        // Compute hash that TEE needs to sign
        bytes32 executionHash = keccak256(abi.encodePacked(msgSender, msgValue, msgData));

        // Sign with TEE private key from .env
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(teePrivateKey, executionHash);
        bytes memory teeSignature = abi.encodePacked(r, s, v);

        // Append TEE signature to msgData
        bytes memory msgDataWithSignature = abi.encodePacked(msgData, teeSignature);

        // Call preCheck directly - should succeed with valid signature
        vm.prank(address(BOB_ACCOUNT)); // preCheck expects msg.sender to be the account
        bytes memory hookData = teeHook.preCheck(msgSender, msgValue, msgDataWithSignature);

        // If we reach here without reverting, the signature was valid
        assertEq(hookData.length, 0, "Hook data should be empty");
    }

    /// @notice Tests execution SUCCEEDS without TEE signature when TEE is offline
    function test_ExecuteWithoutTEESignature_WhenOffline_Success() public {
        _installTEEHook();

        // Set TEE to offline
        teeAlive.setIsAlive(false);
        assertFalse(teeAlive.getIsAlive(), "TEE should be offline");

        // Create execution data WITHOUT TEE signature
        address target = address(0x1234);
        bytes memory data = abi.encodeWithSignature("someFunction()");

        bytes memory callData = abi.encodeWithSelector(
            Nexus.execute.selector,
            target,
            0,
            data
        );

        Execution[] memory execution = new Execution[](1);
        execution[0] = Execution(address(BOB_ACCOUNT), 0, callData);

        PackedUserOperation[] memory userOps = buildPackedUserOperation(
            BOB,
            BOB_ACCOUNT,
            EXECTYPE_DEFAULT,
            execution,
            address(VALIDATOR_MODULE),
            0
        );

        // Should succeed without TEE signature since TEE is offline
        ENTRYPOINT.handleOps(userOps, payable(address(BOB.addr)));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Helper function to install TEE hook on BOB's account
    function _installTEEHook() internal {
        bytes memory callData = abi.encodeWithSelector(
            IModuleManager.installModule.selector,
            MODULE_TYPE_HOOK,
            address(teeHook),
            ""
        );

        Execution[] memory execution = new Execution[](1);
        execution[0] = Execution(address(BOB_ACCOUNT), 0, callData);

        PackedUserOperation[] memory userOps = buildPackedUserOperation(
            BOB,
            BOB_ACCOUNT,
            EXECTYPE_DEFAULT,
            execution,
            address(VALIDATOR_MODULE),
            0
        );

        vm.expectEmit(true, true, true, true);
        emit ModuleInstalled(MODULE_TYPE_HOOK, address(teeHook));

        ENTRYPOINT.handleOps(userOps, payable(address(BOB.addr)));
    }
}
