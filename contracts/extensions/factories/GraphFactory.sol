// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Graph} from "contracts/core/primitives/graph/Graph.sol";
import {RuleChange, KeyValue} from "contracts/core/types/Types.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {ProxyAdmin} from "contracts/core/upgradeability/ProxyAdmin.sol";
import {PrimitiveFactory} from "contracts/extensions/factories/PrimitiveFactory.sol";

contract GraphFactory is PrimitiveFactory {
    event Sense_GraphFactory_Deployment(address indexed graph, string metadataURI);

    constructor(address primitiveBeacon, address proxyAdminLock, address senseFactory)
        PrimitiveFactory(primitiveBeacon, proxyAdminLock, senseFactory)
    {}

    function deployGraph(
        string memory metadataURI,
        IAccessControl accessControl,
        address proxyAdminOwner,
        RuleChange[] calldata ruleChanges,
        KeyValue[] calldata extraData
    ) external onlySenseFactory returns (address) {
        address proxyAdmin = address(new ProxyAdmin(proxyAdminOwner, PROXY_ADMIN_LOCK));
        Graph graph = Graph(address(new BeaconProxy(proxyAdmin, PRIMITIVE_BEACON)));
        graph.initialize(metadataURI, TEMPORARY_ACCESS_CONTROL);
        graph.changeGraphRules(ruleChanges);
        graph.setExtraData(extraData);
        graph.setAccessControl(accessControl);
        emit Sense_GraphFactory_Deployment(address(graph), metadataURI);
        return address(graph);
    }
}
