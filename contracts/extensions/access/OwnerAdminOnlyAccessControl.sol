// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Events} from "contracts/core/types/Events.sol";
import {RoleBasedAccessControl} from "contracts/core/access/RoleBasedAccessControl.sol";
import {Access} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {ILock} from "contracts/core/interfaces/ILock.sol";

contract OwnerAdminOnlyAccessControl is RoleBasedAccessControl {
    ILock immutable LOCK;

    /// @custom:keccak sense.role.Admin
    uint256 constant ADMIN_ROLE_ID = uint256(0x71c974ef9fdb491e0205241d7438e2a707f089c8d115d0101d9f8b73f6745f88);
    /// @custom:keccak sense.contract.AccessControl.OwnerAdminOnlyAccessControl
    bytes32 constant OWNER_ADMIN_ONLY_CONTRACT_TYPE = 0x07aa4da7d7ae721c5bdd2e33039a00ac0bd7c1a9ac609c56acba46799ea97017;

    constructor(address owner, address lock) RoleBasedAccessControl(owner) {
        _setAccess(ADMIN_ROLE_ID, ANY_CONTRACT_ADDRESS, ANY_PERMISSION_ID, Access.GRANTED);
        LOCK = ILock(lock);
        LOCK.isLocked(); // Aims to verify the given address follows ILock interface
    }

    function _beforeGrantingRole(address account, uint256 roleId) internal virtual override {
        require(roleId == ADMIN_ROLE_ID, Errors.InvalidParameter());
        super._beforeGrantingRole(account, roleId);
    }

    function canChangeAccessControl(address account, address /* contractAddress */ )
        external
        view
        virtual
        override
        returns (bool)
    {
        return account == owner() && !LOCK.isLocked();
    }

    function _beforeSettingAccess(
        uint256, /*roleId*/
        address, /*contractAddress*/
        uint256, /*permissionId*/
        Access /*access*/
    ) internal virtual override {
        revert Errors.NotImplemented();
    }

    function getType() external pure virtual override returns (bytes32) {
        return OWNER_ADMIN_ONLY_CONTRACT_TYPE;
    }

    function _emitSenseContractDeployedEvent() internal virtual override {
        emit Events.Sense_Contract_Deployed({
            contractType: "sense.contract.AccessControl",
            flavour: "sense.contract.AccessControl.OwnerAdminOnlyAccessControl"
        });
    }
}
