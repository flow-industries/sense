// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";
import {PrimitiveFactory} from "contracts/extensions/factories/PrimitiveFactory.sol";

contract GroupFactory is PrimitiveFactory {
    event Sense_GroupFactory_Deployment(address indexed group, string metadataURI);

    constructor(address primitiveBeacon, address proxyAdminLock, address senseFactory)
        PrimitiveFactory(primitiveBeacon, proxyAdminLock, senseFactory)
    {}

    function deployGroup(
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData,
        address foundingMember
    ) external onlySenseFactory returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, PROXY_ADMIN_LOCK));
        Group group = Group(address(new BeaconProxy(proxyAdmin, PRIMITIVE_BEACON)));
        group.initialize(metadataURI, TEMPORARY_ACCESS_CONTROL, foundingMember);
        group.changeGroupRules(ruleChanges);
        group.setExtraData(extraData);
        group.setAccessControl(accessControl);
        emit Sense_GroupFactory_Deployment(address(group), metadataURI);
        return address(group);
    }
}
