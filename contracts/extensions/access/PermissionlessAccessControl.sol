// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

contract PermissionlessAccessControl is IAccessControl {
    /// @custom:keccak sense.contract.AccessControl.PermissionlessAccessControl
    bytes32 constant CONTRACT_TYPE = 0xf6e0f0d2a8e84afb10350fa4cef611d207548d418b0522247ce544d679667d2c;

    function getType() external pure returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function canChangeAccessControl(address, /* account */ address /* contractAddress */ )
        external
        pure
        returns (bool)
    {
        return true;
    }

    function hasAccess(address, /* account */ address, /* contractAddress */ uint256 /* permissionId */ )
        external
        pure
        returns (bool)
    {
        return true;
    }
}
