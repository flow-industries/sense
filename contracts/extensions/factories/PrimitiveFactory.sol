// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract PrimitiveFactory {
    IAccessControl internal immutable TEMPORARY_ACCESS_CONTROL;
    address internal immutable PRIMITIVE_BEACON;
    address internal immutable PROXY_ADMIN_LOCK;

    address internal immutable SENSE_FACTORY;

    modifier onlySenseFactory() {
        require(msg.sender == SENSE_FACTORY, Errors.AccessDenied());
        _;
    }

    constructor(address primitiveBeacon, address proxyAdminLock, address senseFactory) {
        TEMPORARY_ACCESS_CONTROL = new PermissionlessAccessControl();
        PRIMITIVE_BEACON = primitiveBeacon;
        PROXY_ADMIN_LOCK = proxyAdminLock;
        SENSE_FACTORY = senseFactory;
    }
}
