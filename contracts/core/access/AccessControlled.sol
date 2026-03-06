// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {IAccessControlled} from "contracts/core/interfaces/IAccessControlled.sol";

abstract contract AccessControlled is IAccessControlled {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Sense_AccessControlAdded(address indexed accessControl, bytes32 indexed accessControlType);
    event Sense_AccessControlUpdated(address indexed accessControl, bytes32 indexed accessControlType);

    struct AccessControlledStorage {
        address accessControl;
    }

    /// @custom:keccak sense.storage.AccessControlledStorage.AccessControlledStorage
    bytes32 constant STORAGE__ACCESS_CONTROLLED = 0x88ade596d415ad0f2be80f1ceda562a3773046109a629a9f36d6886453c62629;

    function $accessControlledStorage() private pure returns (AccessControlledStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ACCESS_CONTROLLED
        }
    }

    function _initialize(IAccessControl accessControl) internal {
        accessControl.verifyHasAccessFunction();
        _setAccessControl(accessControl);
    }

    function _emitPIDs() internal virtual {}

    function _requireAccess(address account, uint256 permissionId) internal view {
        _accessControl().requireAccess(account, permissionId);
    }

    function _hasAccess(address account, uint256 permissionId) internal view returns (bool) {
        return _accessControl().hasAccess(account, permissionId);
    }

    // Access Controlled Functions
    function setAccessControl(IAccessControl newAccessControl) external {
        _accessControl().requireCanChangeAccessControl(msg.sender);
        newAccessControl.verifyHasAccessFunction();
        _setAccessControl(newAccessControl);
    }

    // Internal functions

    function _accessControl() internal view returns (IAccessControl) {
        return IAccessControl($accessControlledStorage().accessControl);
    }

    function _setAccessControl(IAccessControl newAccessControl) internal {
        address oldAccessControl = $accessControlledStorage().accessControl;
        $accessControlledStorage().accessControl = address(newAccessControl);
        if (oldAccessControl == address(0)) {
            emit Sense_AccessControlAdded(address(newAccessControl), newAccessControl.getType());
        } else {
            emit Sense_AccessControlUpdated(address(newAccessControl), newAccessControl.getType());
        }
    }

    // Getters

    function getAccessControl() external view override returns (IAccessControl) {
        return _accessControl();
    }
}
