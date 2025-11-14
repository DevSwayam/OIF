// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TEEAlive {
    bool public isAlive;
    constructor() {
        isAlive = true;
    }
    function setIsAlive(bool _isAlive) external {
        isAlive = _isAlive;
    }
    function getIsAlive() external view returns (bool) {
        return isAlive;
    }
}