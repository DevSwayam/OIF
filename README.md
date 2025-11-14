[![Biconomy](https://img.shields.io/badge/Made_with_%F0%9F%8D%8A_by-Biconomy-ff4e17?style=flat)](https://biconomy.io) [![License MIT](https://img.shields.io/badge/License-MIT-blue?&style=flat)](./LICENSE) [![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg)](https://hardhat.org/) [![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFBD10.svg)](https://getfoundry.sh/)

![Codecov Hardhat Coverage](https://img.shields.io/badge/90%25-green?style=flat&logo=codecov&label=Hardhat%20Coverage) ![Codecov Foundry Coverage](https://img.shields.io/badge/100%25-brightgreen?style=flat&logo=codecov&label=Foundry%20Coverage)

# OIF (Omnichain Intents Framework) with Nexus 🚀

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/bcnmy/nexus)

This repository combines **Nexus** (ERC-7579 Modular Smart Account Base) with the **OIF** (Omnichain Intents Framework) for cross-chain intents and operations. It provides a comprehensive foundation for building cross-chain smart account applications with account abstraction (ERC-4337) and modular architecture (ERC-7579).

## What's Included

- **Nexus Smart Accounts**: Biconomy's modular smart account implementation
- **OIF Framework**: Input/Output oracles and escrow contracts for cross-chain intents
- **Account Abstraction**: ERC-4337 implementation with paymasters and bundlers
- **Modular Architecture**: ERC-7579 compatible validators, executors, hooks, and fallback handlers
- **Integration Handlers**: CATS multicall and other cross-chain integrations

Documentation: (https://github.com/bcnmy/nexus/wiki)

## 📚 Table of Contents

- [Nexus - ERC-7579 Modular Smart Account Base 🚀](#nexus---erc-7579-modular-smart-account-base-)
  - [📚 Table of Contents](#-table-of-contents)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
  - [🛠️ Essential Scripts](#️-essential-scripts)
    - [🏗️ Build Contracts](#️-build-contracts)
    - [🧪 Run Tests](#-run-tests)
    - [⛽ Gas Report](#-gas-report)
    - [📊 Coverage Report](#-coverage-report)
    - [📄 Documentation](#-documentation)
    - [🚀 Deploy Contracts](#-deploy-contracts)
    - [🎨 Lint Code](#-lint-code)
    - [🖌️ Auto-fix Linting Issues](#️-auto-fix-linting-issues)
    - [🚀 Generating Storage Layout](#-generating-storage-layout)
  - [🔒 Security Audits](#-security-audits)
  - [License](#license)
  - [Connect with Biconomy 🍊](#connect-with-biconomy-)

## 📁 Project Structure

```
OIF/
├── contracts/              # Smart contract source files
│   ├── base/              # Base contracts (ModuleManager, ExecutionHelper, BaseAccount)
│   ├── factory/           # Account factories (NexusAccountFactory, BiconomyMetaFactory)
│   ├── modules/           # Validators, executors, hooks, and fallback handlers
│   │   ├── validators/    # K1Validator (ECDSA), WebAuthn validators
│   │   ├── executors/     # Executor modules
│   │   └── hooks/         # Hook modules
│   ├── input/             # OIF Input oracle and escrow contracts
│   │   ├── escrow/        # InputSettlerEscrow.sol
│   │   └── vault/         # InputVault.sol
│   ├── oracle/            # Oracle implementations (OracleBase.sol)
│   ├── integrations/      # Cross-chain integration handlers
│   │   └── CatsMulticallHandler.sol
│   ├── mocks/             # Mock contracts for testing
│   │   ├── MockPaymaster.sol
│   │   └── VerifyingPaymaster.sol (custom implementation)
│   ├── lib/               # Library contracts (ModeLib, ExecLib, BootstrapLib)
│   ├── interfaces/        # Contract interfaces
│   ├── types/             # Type definitions and constants
│   └── Nexus.sol          # Main modular smart account contract
├── test/                  # Test files
│   ├── foundry/           # Foundry tests
│   │   ├── unit/          # Unit tests
│   │   │   ├── concrete/  # Concrete implementation tests
│   │   │   └── fuzz/      # Fuzz tests
│   │   └── utils/         # Test utilities (TestHelper, NexusTest_Base)
│   ├── input/             # Input-related tests (from oif-contracts)
│   └── oracle/            # Oracle-related tests (from oif-contracts)
├── scripts/               # Deployment and utility scripts
├── lib/                   # Git submodule dependencies
│   ├── forge-std/         # Foundry standard library
│   ├── openzeppelin-contracts/  # OpenZeppelin contracts
│   ├── permit2/           # Uniswap Permit2
│   ├── the-compact/       # Compact signatures
│   └── broadcaster/       # Cross-chain messaging
├── node_modules/          # NPM dependencies
│   ├── account-abstraction/  # ERC-4337 implementation (v0.7.0)
│   ├── solady/            # Gas-optimized utilities
│   ├── erc7579/           # ERC-7579 interfaces
│   └── @biconomy/composability/  # Composable execution
├── foundry.toml           # Foundry configuration
├── remappings.txt         # Solidity import remappings
├── package.json           # NPM dependencies and scripts
└── README.md              # This file
```

## Getting Started

To kickstart, follow these steps:

### Prerequisites

- **Node.js** (v18.x or later)
- **Yarn** or **npm**
- **Foundry** (Refer to [Foundry installation instructions](https://book.getfoundry.sh/getting-started/installation))
- **Git** with submodule support

### Installation

1. **Clone the repository:**

```bash
git clone <repository-url>
cd OIF
```

2. **Initialize git submodules:**

The project uses git submodules for Foundry library dependencies:

```bash
git submodule update --init --recursive
```

This will install:
- `forge-std`: Foundry testing utilities
- `openzeppelin-contracts`: OpenZeppelin contract library
- `permit2`: Uniswap Permit2 for gasless approvals
- `the-compact`: Compact signature utilities
- `broadcaster`: Cross-chain message broadcasting

3. **Install NPM dependencies:**

```bash
npm install --legacy-peer-deps
```

**Note**: The `--legacy-peer-deps` flag is required due to peer dependency conflicts in some packages.

Key dependencies installed:
- `account-abstraction@v0.7.0`: ERC-4337 reference implementation from eth-infinitism
- `solady`: Gas-optimized Solidity utilities
- `erc7579`: ERC-7579 modular account interfaces
- `@biconomy/composability`: Composable execution framework
- Various utility libraries (sentinellist, excessively-safe-call, etc.)

### Configuration Files

#### Foundry Configuration (`foundry.toml`)

The project is configured to use:
- **Solidity Version**: 0.8.30
- **EVM Version**: Cancun
- **Optimizer**: Enabled with 100M runs
- **Via IR**: Enabled for better optimization
- **Source Directory**: `contracts/`
- **Test Directory**: `test/`

#### Import Remappings (`remappings.txt`)

Custom import remappings are configured to resolve dependencies from both `lib/` (git submodules) and `node_modules/` (npm packages):

```
src/=contracts/
account-abstraction/=node_modules/account-abstraction/contracts/
solady/=node_modules/solady/src/
forge-std/=lib/forge-std/src/
openzeppelin/=lib/openzeppelin-contracts/contracts/
the-compact/=lib/the-compact/
# ... and more
```

## 🛠️ Essential Scripts

Execute key operations for Foundry and Hardhat with these scripts. Append `:forge` or `:hardhat` to run them in the respective environment.

### 🏗️ Build Contracts

```bash
yarn build
```

Compiles contracts for both Foundry and Hardhat.

### 🧪 Run Tests

#### Using Forge (Recommended for OIF)

```bash
# Compile contracts first
forge build

# Run all Foundry tests
forge test

# Run only Foundry unit tests (excluding oif-contracts tests)
forge test --match-path "test/foundry/**/*.t.sol"

# Run specific test contract
forge test --match-contract TestAccountConfig_AccountId

# Run specific test function
forge test --match-test test_WhenCheckingTheAccountID

# Run with verbose output (show traces)
forge test -vv        # Basic traces
forge test -vvv       # Detailed traces with logs
forge test -vvvv      # Full traces with opcodes

# Run fuzz tests
forge test --match-path "test/foundry/unit/fuzz/*.t.sol"
```

#### Using Yarn/Hardhat

```bash
yarn test
```

#### Current Test Status

**Compilation**: ✅ Successfully compiles ~406 files with Solc 0.8.30

**Test Results** (Foundry):
- **Passed**: 9 tests
  - Simple unit tests that don't require EntryPoint operations
  - Example: `TestAccountConfig_AccountId::test_WhenCheckingTheAccountID`

- **Failed**: 54 tests
  - All failing with `Reentrancy()` error during `setUp()`
  - Related to account deployment via `ENTRYPOINT.handleOps()`
  - Affects tests that deploy Nexus accounts through the EntryPoint

**Known Issues**:

The majority of tests currently fail during setup with a `Reentrancy()` error when deploying accounts. This is likely related to:
1. Transient storage (tstore/tload) usage in reentrancy guards
2. Version compatibility between contracts and test infrastructure
3. Account initialization flow triggering reentrancy protection

Tests that don't involve EntryPoint operations pass successfully.

### ⛽ Gas Report

```bash
yarn test:gas
```

Creates detailed reports for test coverage.

### 📊 Coverage Report

```bash
yarn coverage
```

Creates detailed reports for test coverage.

### 📄 Documentation

```bash
yarn docs
```

Generate documentation from NatSpec comments.

### 🚀 Deploy Contracts

Nexus contracts are pre-deployed on most EVM chains.
Please see the addresses [here](https://docs.biconomy.io/contractsAndAudits).

If you need to deploy Nexus on your own chain or you want to deploy the contracts with different addresses, please see [this](https://github.com/bcnmy/nexus/tree/deploy-v1.0.1/scripts/bash-deploy) script. Or the same script on different deploy branches.

### 🎨 Lint Code

```bash
yarn lint
```

Checks code for style and potential errors.

### 🖌️ Auto-fix Linting Issues

```bash
yarn lint:fix
```

Automatically fixes linting problems found.

### 🚀 Generating Storage Layout

```bash
yarn check
```

To generate reports of the storage layout for potential upgrades safety using `hardhat-storage-layout`.

🔄 Add `:forge` or `:hardhat` to any script above to target only Foundry or Hardhat environment, respectively.

## 🏗️ Key Contracts and Architecture

### Core Nexus Contracts

#### Nexus.sol
The main modular smart account contract implementing:
- **ERC-4337 Account Abstraction**: UserOperation validation and execution
- **ERC-7579 Modular Architecture**: Support for validators, executors, hooks, and fallback handlers
- **UUPS Upgradeable**: Secure upgrade pattern
- **Composable Execution**: Support for complex multi-step operations

Key features:
- Module management (install/uninstall validators, executors, hooks)
- Execution modes (single/batch, try/revert)
- Emergency module uninstallation with timelock
- Support for EIP-712 typed data signing

#### Account Factories

**NexusAccountFactory.sol**: Creates deterministic Nexus account addresses using CREATE2
**BiconomyMetaFactory.sol**: Meta-factory that manages multiple account factory implementations

#### Module System

**Validators** (`contracts/modules/validators/`)
- Validate signatures and user operations
- Example: `K1Validator.sol` for ECDSA signatures

**Executors** (`contracts/modules/executors/`)
- Execute operations on behalf of the account
- Can be granted specific permissions

**Hooks** (`contracts/modules/hooks/`)
- Pre-execution and post-execution hooks
- Can enforce custom logic before/after operations

**Fallback Handlers** (`contracts/modules/fallback/`)
- Handle unknown function calls
- Extend account functionality dynamically

### OIF Framework Contracts

#### Input System (`contracts/input/`)

**InputSettlerEscrow.sol**
- Escrow contract for cross-chain input settlement
- Handles input validation and settlement
- Supports multiple signature types
- Reentrancy protection for secure operations

**InputVault.sol**
- Vault for managing input assets
- Secure storage and withdrawal mechanisms

#### Oracle System (`contracts/oracle/`)

**OracleBase.sol**
- Base implementation for oracles
- Handles cross-chain data verification
- Configurable trust models

#### Integration Handlers (`contracts/integrations/`)

**CatsMulticallHandler.sol**
- Handler for CATS protocol multicall operations
- Supports input/output callbacks
- Implements `IInputCallback` and `IOutputCallback`
- Reentrancy-protected operations

### Account Abstraction Flow

```
User creates UserOperation
       ↓
Bundler submits to EntryPoint
       ↓
EntryPoint validates via Validator module
       ↓
[Optional] Paymaster sponsors gas
       ↓
EntryPoint executes operation on Account
       ↓
[Optional] Hooks run pre/post execution
       ↓
Operation completes
```

### Module Installation Flow

```
Account.installModule()
       ↓
Validates module type and address
       ↓
Calls module.onInstall(data)
       ↓
Adds module to appropriate registry
       ↓
Emits ModuleInstalled event
```

### Cross-Chain Intent Flow (OIF)

```
User submits intent
       ↓
Input Oracle validates intent
       ↓
InputSettlerEscrow locks assets
       ↓
Cross-chain operation executes
       ↓
Output Oracle verifies completion
       ↓
Escrow releases assets
```

## 🔒 Security Audits

**Note**: The Nexus smart account contracts have been audited. OIF-specific contracts should undergo additional security review before production use.

| Auditor          | Date       | Final Report Link       |
| ---------------- | ---------- | ----------------------- |
| CodeHawks-Cyfrin | 17-09-2024 | [View Report](./audits/CodeHawks-Cyfrin-17-09-2024.pdf) |
| Spearbit         | 10/11-2024 | [View Report](./audits/report-cantinacode-biconomy-0708-final.pdf) / [View Add-on](./audits/report-cantinacode-biconomy-erc7739-addon-final.pdf) |
| Zenith           | 03-2025 | [View Report](./audits/Biconomy-Nexus_Zenith-Audit-Report.pdf) |
| Pashov           | 03-2025 | [View Report](./audits/Nexus-Pashov-Review_2025-03.pdf) |

## 🛠️ Troubleshooting

### Common Issues

#### 1. Git Submodules Not Initialized
**Error**: Missing files in `lib/` directory or compilation errors about missing imports.

**Solution**:
```bash
git submodule update --init --recursive
```

#### 2. NPM Dependency Conflicts
**Error**: `ERESOLVE unable to resolve dependency tree`

**Solution**:
```bash
npm install --legacy-peer-deps
```

#### 3. Compilation Errors with EVM Version
**Error**: Unsupported opcodes or EVM version errors

**Solution**: Ensure `foundry.toml` has `evm_version = "cancun"` (not "prague")

#### 4. Import Resolution Failures
**Error**: `Unable to resolve imports`

**Solution**: Check `remappings.txt` has the correct paths:
```bash
forge remappings  # View current remappings
```

#### 5. Test Failures with Reentrancy Error
**Error**: Tests fail with `Reentrancy()` during `setUp()`

**Current Status**: Known issue affecting 54 tests. Tests that don't involve EntryPoint account deployment work correctly.

**Workaround**: Run only passing tests:
```bash
forge test --match-test test_WhenCheckingTheAccountID
```

### Clearing Build Artifacts

If you encounter strange compilation or test issues:

```bash
# Clean Foundry artifacts
forge clean

# Rebuild
forge build

# Clean node_modules (nuclear option)
rm -rf node_modules
npm install --legacy-peer-deps
```

## 📚 Resources and Documentation

### ERC Standards
- [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579)
- [ERC-1271: Standard Signature Validation](https://eips.ethereum.org/EIPS/eip-1271)
- [ERC-712: Typed Structured Data Hashing](https://eips.ethereum.org/EIPS/eip-712)

### Development Tools
- [Foundry Book](https://book.getfoundry.sh/) - Comprehensive Foundry documentation
- [Hardhat Documentation](https://hardhat.org/docs) - Hardhat development environment
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) - Secure smart contract library
- [Solady Documentation](https://github.com/Vectorized/solady) - Gas-optimized Solidity utilities

### Biconomy Resources
- [Biconomy Documentation](https://docs.biconomy.io/)
- [Nexus GitHub](https://github.com/bcnmy/nexus)
- [Nexus Wiki](https://github.com/bcnmy/nexus/wiki)

### Account Abstraction Resources
- [ERC-4337 Official Site](https://www.erc4337.io/)
- [Account Abstraction GitHub](https://github.com/eth-infinitism/account-abstraction)
- [Bundler Specification](https://github.com/eth-infinitism/bundler-spec)

## 🤝 Contributing

When contributing to this repository:

1. **Fork the repository** and create your branch from `main`
2. **Write tests** for any new features or bug fixes
3. **Ensure all tests pass**: Run `forge test` and `yarn test`
4. **Follow the existing code style**: Use `yarn lint` to check
5. **Update documentation**: Keep README and NatSpec comments current
6. **Submit a pull request** with a clear description of changes

### Development Workflow

```bash
# 1. Create a feature branch
git checkout -b feature/your-feature-name

# 2. Make your changes
# Edit contracts in contracts/
# Add tests in test/foundry/unit/

# 3. Test your changes
forge build
forge test

# 4. Check code style
yarn lint

# 5. Commit and push
git add .
git commit -m "feat: add your feature description"
git push origin feature/your-feature-name

# 6. Open a pull request on GitHub
```

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Connect with Biconomy 🍊

[![Website](https://img.shields.io/badge/🍊-Website-ff4e17?style=for-the-badge&logoColor=white)](https://biconomy.io) [![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/biconomy) [![Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/biconomy) [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/company/biconomy) [![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/biconomy) [![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/channel/UC0CtA-Dw9yg-ENgav_VYjRw) [![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/bcnmy/)
