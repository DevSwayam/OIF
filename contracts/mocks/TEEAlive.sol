// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title TEEAlive
/// @notice Mock contract to simulate TEE (Trusted Execution Environment) alive status
/// @dev This contract allows toggling the TEE online/offline status for testing purposes
contract TEEAlive {
    bool public isAlive;

    /// @notice Event emitted when TEE alive status changes
    event TEEStatusChanged(bool newStatus);

    /// @notice Creates a new TEEAlive contract with TEE initially online
    constructor() {
        isAlive = true;
    }

    /// @notice Sets the TEE alive status
    /// @param _isAlive New alive status (true = online, false = offline)
    function setIsAlive(bool _isAlive) external {
        isAlive = _isAlive;
        emit TEEStatusChanged(_isAlive);
    }

    /// @notice Gets the current TEE alive status
    /// @return Current alive status
    function getIsAlive() external view returns (bool) {
        return isAlive;
    }
}
