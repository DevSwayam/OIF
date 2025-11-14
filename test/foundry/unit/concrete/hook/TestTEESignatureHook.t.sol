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

    event TEESignatureVerified(address indexed account, bytes32 indexed hash);
    event TEEVerificationBypassed(address indexed account, bytes32 indexed hash);
    event HookInstalled(address indexed account);
    event HookUninstalled(address indexed account);

    /// @notice Sets up the testing environment
    function setUp() public {
        init();

        // Deploy TEEAlive contract
        teeAlive = new TEEAlive();

        // Deploy TEESignatureHook with TEEAlive contract
        teeHook = new TEESignatureHook(address(teeAlive));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INSTALLATION TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Tests successful installation of TEE hook
    function test_InstallTEEHook_Success() public {
        assertFalse(
            BOB_ACCOUNT.isModuleInstalled(MODULE_TYPE_HOOK, address(teeHook), ""),
            "TEE hook should not be installed initially"
        );

        _installTEEHook();

        assertTrue(
            BOB_ACCOUNT.isModuleInstalled(MODULE_TYPE_HOOK, address(teeHook), ""),
            "TEE hook should be installed"
        );

        assertEq(BOB_ACCOUNT.getActiveHook(), address(teeHook), "TEE hook should be active");
    }

    /// @notice Tests successful uninstallation of TEE hook
    function test_UninstallTEEHook_Success() public {
        test_InstallTEEHook_Success();

        // Set TEE to offline so preCheck doesn't require signature during uninstall
        teeAlive.setIsAlive(false);

        bytes memory callData = abi.encodeWithSelector(
            IModuleManager.uninstallModule.selector,
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
        emit ModuleUninstalled(MODULE_TYPE_HOOK, address(teeHook));

        ENTRYPOINT.handleOps(userOps, payable(address(BOB.addr)));

        assertFalse(
            BOB_ACCOUNT.isModuleInstalled(MODULE_TYPE_HOOK, address(teeHook), ""),
            "TEE hook should be uninstalled"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                        TEE OFFLINE SCENARIO TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Tests execution succeeds WITHOUT TEE signature when TEE is offline
    function test_ExecuteWithoutTEESignature_WhenOffline_Success() public {
        test_InstallTEEHook_Success();

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

    /// @notice Tests TEE status can be toggled
    function test_ToggleTEEStatus() public {
        assertTrue(teeHook.isTEEAlive(), "TEE should be online initially");

        teeAlive.setIsAlive(false);
        assertFalse(teeHook.isTEEAlive(), "TEE should be offline after toggle");

        teeAlive.setIsAlive(true);
        assertTrue(teeHook.isTEEAlive(), "TEE should be online after toggle back");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Tests getTEESignerAddress returns correct address
    function test_GetTEESignerAddress() public view {
        assertEq(
            teeHook.getTEESignerAddress(),
            0xAF9fC206261DF20a7f2Be9B379B101FAFd983117,
            "Should return correct TEE signer address"
        );
    }

    /// @notice Tests getTEEAliveContract returns correct address
    function test_GetTEEAliveContract() public view {
        assertEq(
            teeHook.getTEEAliveContract(),
            address(teeAlive),
            "Should return correct TEEAlive contract address"
        );
    }

    /// @notice Tests isTEEAlive reflects TEEAlive contract state
    function test_IsTEEAlive() public {
        assertTrue(teeHook.isTEEAlive(), "TEE should be alive initially");

        teeAlive.setIsAlive(false);
        assertFalse(teeHook.isTEEAlive(), "TEE should be dead after setIsAlive(false)");

        teeAlive.setIsAlive(true);
        assertTrue(teeHook.isTEEAlive(), "TEE should be alive after setIsAlive(true)");
    }

    /// @notice Tests hook correctly identifies its module type
    function test_IsModuleType() public view {
        assertTrue(teeHook.isModuleType(MODULE_TYPE_HOOK), "Should identify as HOOK type");
        assertFalse(teeHook.isModuleType(MODULE_TYPE_VALIDATOR), "Should not identify as VALIDATOR type");
        assertFalse(teeHook.isModuleType(MODULE_TYPE_EXECUTOR), "Should not identify as EXECUTOR type");
    }

    /// @notice Tests initialization status
    function test_IsInitialized() public {
        assertFalse(teeHook.isInitialized(address(BOB_ACCOUNT)), "Should not be initialized before install");

        _installTEEHook();

        assertTrue(teeHook.isInitialized(address(BOB_ACCOUNT)), "Should be initialized after install");
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
