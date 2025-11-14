// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../../utils/Imports.sol";
import "../../../utils/NexusTest_Base.t.sol";
import { ResourceLockModule, MandateOutput, StandardOrder, SolveParams } from "../../../../../contracts/modules/executors/ResourceLockModule.sol";
import { TEESignatureHook } from "../../../../../contracts/modules/hooks/TEESignatureHook.sol";
import { TEEAlive } from "../../../../../contracts/mocks/TEEAlive.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BootstrapLib } from "../../../../../contracts/lib/BootstrapLib.sol";
import { BootstrapPreValidationHookConfig } from "../../../../../contracts/utils/NexusBootstrap.sol";

/// @title MockInputSettler
/// @notice Mock settler contract for testing
contract MockInputSettler {
    event SettlementFinalized(
        address indexed user,
        address indexed token,
        uint256 amount,
        address indexed solver
    );

    /// @notice Finalises an order when called directly by the solver
    function finalise(
        StandardOrder calldata order,
        bytes calldata /* signatures */,
        SolveParams[] calldata solveParams,
        bytes32 destination,
        bytes calldata /* call */
    ) external {
        // Extract the first input (token and amount)
        require(order.inputs.length > 0, "No inputs");

        address token = address(uint160(order.inputs[0][0]));
        uint256 amount = order.inputs[0][1];

        // Pull funds from user's account using transferFrom
        IERC20(token).transferFrom(order.user, address(uint160(uint256(destination))), amount);

        emit SettlementFinalized(order.user, token, amount, address(uint160(uint256(solveParams[0].solver))));
    }
}

/// @title MockERC20
/// @notice Mock ERC20 token for testing
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }
}

/// @title TestResourceLockModule
/// @notice Three core tests for TEE-based settlement flow
contract TestResourceLockModule is NexusTest_Base {
    ResourceLockModule internal resourceLockModule;
    TEESignatureHook internal teeHook;
    TEEAlive internal teeAlive;
    MockInputSettler internal inputSettler;
    MockERC20 internal mockToken;

    Nexus internal userAccount;
    uint256 internal teePrivateKey;
    address internal teeSignerAddress;
    address internal solverAddress;
    Vm.Wallet internal USER;

    /// @notice Sets up the testing environment with modules installed at deployment
    function setUp() public {
        init();

        // Load TEE private key from .env
        teePrivateKey = vm.envUint("PRIVATE_KEY");
        teeSignerAddress = vm.addr(teePrivateKey);

        // Create user wallet
        USER = createAndFundWallet("USER", 1000 ether);

        // Setup solver address
        solverAddress = address(0x999);

        // Deploy contracts
        teeAlive = new TEEAlive();
        teeHook = new TEESignatureHook(address(teeAlive), teeSignerAddress);
        resourceLockModule = new ResourceLockModule(address(teeAlive));
        inputSettler = new MockInputSettler();
        mockToken = new MockERC20();

        // Deploy Nexus account with modules installed in initData
        userAccount = _deployNexusWithModules();

        // Mint tokens to user's account
        mockToken.mint(address(userAccount), 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            THREE CORE TEST CASES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Test 1: User can force exit funds when TEE is offline
    function test_UserCanForceExitWhenTEEOffline() public {
        // Set TEE offline
        teeAlive.setIsAlive(false);
        assertFalse(teeAlive.getIsAlive(), "TEE should be offline");

        // User wants to transfer tokens directly (not through module)
        uint256 transferAmount = 50 ether;
        address recipient = address(0x1111);

        // Create execution to transfer tokens
        Execution[] memory execution = new Execution[](1);
        execution[0] = Execution(
            address(mockToken),
            0,
            abi.encodeWithSelector(MockERC20.transfer.selector, recipient, transferAmount)
        );

        // Build and execute UserOperation WITHOUT TEE signature (TEE is offline)
        PackedUserOperation[] memory userOps = buildPackedUserOperation(
            USER,
            userAccount,
            EXECTYPE_DEFAULT,
            execution,
            address(VALIDATOR_MODULE),
            0
        );

        // Should succeed - TEE offline allows bypass
        ENTRYPOINT.handleOps(userOps, payable(USER.addr));

        // Verify transfer succeeded
        assertEq(mockToken.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
        assertEq(mockToken.balanceOf(address(userAccount)), 950 ether, "User balance should be reduced");
    }

    /// @notice Test 2: User can transact when TEE is online with user signature + TEE signature
    function test_UserCanTransactWithTEEOnline() public {
        // Ensure TEE is online
        assertTrue(teeAlive.getIsAlive(), "TEE should be online");

        // User wants to transfer tokens
        uint256 transferAmount = 50 ether;
        address recipient = address(0x2222);

        // Create execution to transfer tokens
        Execution[] memory execution = new Execution[](1);
        execution[0] = Execution(
            address(mockToken),
            0,
            abi.encodeWithSelector(MockERC20.transfer.selector, recipient, transferAmount)
        );

        // Build UserOperation
        PackedUserOperation[] memory userOps = buildPackedUserOperation(
            USER,
            userAccount,
            EXECTYPE_DEFAULT,
            execution,
            address(VALIDATOR_MODULE),
            0
        );

        // Compute TEE signature over the execution callData
        // The hook will receive msgData = userOps[0].callData
        bytes32 executionHash = keccak256(abi.encodePacked(
            address(ENTRYPOINT), // msg.sender
            uint256(0), // msg.value
            userOps[0].callData // the actual calldata that will be executed
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(teePrivateKey, executionHash);
        bytes memory teeSignature = abi.encodePacked(r, s, v);

        // Append TEE signature to callData and re-sign UserOp
        userOps[0].callData = abi.encodePacked(userOps[0].callData, teeSignature);
        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOps[0]);
        userOps[0].signature = signMessage(USER, userOpHash);

        // Should succeed - both user and TEE signatures present
        ENTRYPOINT.handleOps(userOps, payable(USER.addr));

        // Verify transfer succeeded
        assertEq(mockToken.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
        assertEq(mockToken.balanceOf(address(userAccount)), 950 ether, "User balance should be reduced");
    }

    /// @notice Test 3: Module can approve settler and execute settlement with just TEE signature
    function test_ModuleCanExecuteSettlementWithTEESignature() public {
        // Ensure TEE is online
        assertTrue(teeAlive.getIsAlive(), "TEE should be online");

        // Prepare settlement parameters
        uint256 settlementAmount = 100 ether;
        uint256 nonce = 0;

        // Create StandardOrder
        StandardOrder memory order = _createStandardOrder(
            address(userAccount),
            nonce,
            settlementAmount
        );

        // Create SolveParams
        SolveParams[] memory solveParams = new SolveParams[](1);
        solveParams[0] = SolveParams({
            timestamp: uint32(block.timestamp),
            solver: bytes32(uint256(uint160(solverAddress)))
        });

        // Create TEE signature for the approval execution
        bytes memory teeSignature = _createTEESignatureForApproval(
            address(mockToken),
            settlementAmount,
            address(inputSettler)
        );

        // Step 1: Module executes approval from solver (NO user signature needed - module is permissionless)
        vm.prank(solverAddress);
        resourceLockModule.executeSettlement(
            address(userAccount),
            address(mockToken),
            settlementAmount,
            address(inputSettler),
            bytes(""), // settlerData no longer used by module
            nonce,
            teeSignature
        );

        // Verify approval succeeded and nonce incremented
        assertEq(mockToken.allowance(address(userAccount), address(inputSettler)), settlementAmount, "Approval should be set");
        assertEq(resourceLockModule.getNonce(address(userAccount)), 1, "Nonce should be incremented");

        // Step 2: Solver calls inputSettler.finalise() to pull funds
        vm.prank(solverAddress);
        inputSettler.finalise(
            order,
            bytes(""), // signatures
            solveParams,
            bytes32(uint256(uint160(solverAddress))), // destination (solver)
            bytes("") // call data
        );

        // Verify settlement completed - funds transferred
        assertEq(mockToken.balanceOf(address(userAccount)), 900 ether, "User balance should be reduced");
        assertEq(mockToken.balanceOf(solverAddress), 100 ether, "Solver should receive tokens");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deploy Nexus account with modules installed in initData
    function _deployNexusWithModules() internal returns (Nexus) {
        // Prepare module installations
        bytes memory moduleInitData = abi.encodePacked(USER.addr);
        BootstrapConfig[] memory validators = BootstrapLib.createArrayConfig(address(VALIDATOR_MODULE), moduleInitData);
        BootstrapConfig memory hook = BootstrapLib.createSingleConfig(address(teeHook), "");
        BootstrapConfig[] memory executors = BootstrapLib.createArrayConfig(address(resourceLockModule), "");
        BootstrapConfig[] memory fallbacks = BootstrapLib.createArrayConfig(address(0), "");

        bytes memory saDeploymentIndex = abi.encodePacked(USER.addr, "RESOURCE_LOCK_TEST");

        // Create initData for BOOTSTRAPPER - using initNexusNoRegistry
        bytes memory _initData = abi.encode(
            address(BOOTSTRAPPER),
            abi.encodeCall(
                BOOTSTRAPPER.initNexusNoRegistry,
                (validators, executors, hook, fallbacks, new BootstrapPreValidationHookConfig[](0))
            )
        );

        bytes32 salt = keccak256(saDeploymentIndex);

        // Deploy account with modules
        vm.prank(USER.addr);
        Nexus account = Nexus(payable(FACTORY.createAccount(_initData, salt)));

        // Fund account
        vm.deal(address(account), 100 ether);

        return account;
    }

    /// @notice Helper to create StandardOrder
    function _createStandardOrder(
        address user,
        uint256 nonce,
        uint256 amount
    ) internal view returns (StandardOrder memory) {
        uint256[2][] memory inputs = new uint256[2][](1);
        inputs[0][0] = uint256(uint160(address(mockToken)));
        inputs[0][1] = amount;

        MandateOutput[] memory outputs = new MandateOutput[](0);

        return StandardOrder({
            user: user,
            nonce: nonce,
            originChainId: block.chainid,
            expires: uint32(block.timestamp + 1 hours),
            fillDeadline: uint32(block.timestamp + 30 minutes),
            inputOracle: address(0),
            inputs: inputs,
            outputs: outputs
        });
    }

    /// @notice Helper to create TEE signature for approval execution
    function _createTEESignatureForApproval(
        address token,
        uint256 amount,
        address settler
    ) internal view returns (bytes memory) {
        // Create the approval calldata that will be executed
        bytes memory approveCallData = abi.encodeWithSelector(
            IERC20.approve.selector,
            settler,
            amount
        );

        // Encode execution using ExecLib format
        bytes memory execution = ExecLib.encodeSingle(token, 0, approveCallData);

        // Create execution mode
        ExecutionMode mode = ExecutionMode.wrap(
            bytes32(abi.encodePacked(CALLTYPE_SINGLE, EXECTYPE_DEFAULT, bytes4(0x00000000), bytes22(0)))
        );

        // Encode the executeFromExecutor call (ExecutionMode is bytes32 in ABI)
        bytes memory callData = abi.encodeWithSignature(
            "executeFromExecutor(bytes32,bytes)",
            mode,
            execution
        );

        // Compute the hash that TEE will sign (what the hook will see in msg.data)
        // msg.sender = ResourceLockModule address, msg.value = 0
        bytes32 executionHash = keccak256(
            abi.encodePacked(
                address(resourceLockModule), // msg.sender
                uint256(0), // msg.value
                callData // actual execution data
            )
        );

        // Sign with TEE private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(teePrivateKey, executionHash);
        return abi.encodePacked(r, s, v);
    }
}
