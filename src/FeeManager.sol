//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ISwap.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract FeeManager is ISwap, AccessControlUpgradeable, UUPSUpgradeable {
    uint256 public constant FEE_DENOMINATOR = 10000;

    uint256 public fee;

    function initialize(uint256 _fee) external initializer {
        _disableInitializers();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        fee = _fee;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function setFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fee = _fee;
    }

    function getFee(ISwap.SwapData memory swapData) external view returns (uint256) {
        return (swapData.amountToken0 * fee) / FEE_DENOMINATOR;
    }
}
