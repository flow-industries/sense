// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {IApp} from "contracts/extensions/primitives/app/IApp.sol";
import {AppCore as Core} from "contracts/extensions/primitives/app/AppCore.sol";
import {KeyValue, SourceStamp} from "contracts/core/types/Types.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {Events} from "contracts/core/types/Events.sol";
import {BaseSource} from "contracts/core/base/BaseSource.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";

struct AppInitialProperties {
    address graph;
    address[] feeds;
    address namespace;
    address[] groups;
    address defaultFeed;
    address[] signers;
    address paymaster;
    address treasury;
}

contract App is IApp, ExtraDataBased, MetadataBased, Initializable, BaseSource, AccessControlled {
    // Resource IDs involved in the contract

    /// @custom:keccak sense.permission.SetPrimitives
    uint256 constant PID__SET_PRIMITIVES = uint256(0xba9b82400786482994805993d6081e3f985aaa785ccdbca61355ef0cffa8afcb);
    /// @custom:keccak sense.permission.SetSigners
    uint256 constant PID__SET_SIGNERS = uint256(0x40892156888c0cbc2bf6c79c5ea145c37cb4f34dcdd71b9e44d8afac86c22a56);
    /// @custom:keccak sense.permission.SetTreasury
    uint256 constant PID__SET_TREASURY = uint256(0xe7e9b4627d7af430c5fd8578267308898ea541615c4a6da58ff5f95d5f36393d);
    /// @custom:keccak sense.permission.SetPaymaster
    uint256 constant PID__SET_PAYMASTER = uint256(0x8a347572bfcadca377a4cb0e0a4d6cf03ae34fe70b8fe3b1ed39d77bb6648d8b);
    /// @custom:keccak sense.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x89230884684683d91d892d3bd0c063380fe312b990f4c455be670b9b5b0c30c2);
    /// @custom:keccak sense.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xc593734a442ec90a714cfb87bfb7aca283b763335df63d0001196ab1ff115f53);
    /// @custom:keccak sense.permission.SetSourceStampVerification
    uint256 constant PID__SET_SOURCE_STAMP_VERIFICATION =
        uint256(0x455bc5f746f11ad605353c660a742d5e768422042e3eb1498851cfe6540af5fc);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory metadataURI,
        bool isSourceStampVerificationEnabled,
        IAccessControl accessControl,
        AppInitialProperties memory initialProps,
        KeyValue[] calldata extraData
    ) external override initializer {
        _initialize(metadataURI, isSourceStampVerificationEnabled, initialProps, extraData);
        AccessControlled._initialize(accessControl);
    }

    function _initialize(
        string memory metadataURI,
        bool isSourceStampVerificationEnabled,
        AppInitialProperties memory initialProps,
        KeyValue[] calldata extraData
    ) internal {
        _setMetadataURI(metadataURI);

        _setSourceStampVerification(isSourceStampVerificationEnabled);
        if (initialProps.treasury != address(0)) {
            _setTreasury(initialProps.treasury);
        }
        if (initialProps.graph != address(0)) {
            _setGraph(initialProps.graph);
        }
        _addFeeds(initialProps.feeds);
        if (initialProps.namespace != address(0)) {
            _setNamespace(initialProps.namespace);
        }
        _addGroups(initialProps.groups);
        if (initialProps.defaultFeed != address(0)) {
            _setDefaultFeed(initialProps.defaultFeed);
        }
        _addSigners(initialProps.signers);
        if (initialProps.paymaster != address(0)) {
            _setPaymaster(initialProps.paymaster);
        }
        _setExtraData(extraData);

        _emitPIDs();

        emit Events.Sense_Contract_Deployed({contractType: "sense.contract.App", flavour: "sense.contract.App"});
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Sense_PermissionId_Available(PID__SET_PRIMITIVES, "SET_PRIMITIVES");
        emit Events.Sense_PermissionId_Available(PID__SET_SIGNERS, "SET_SIGNERS");
        emit Events.Sense_PermissionId_Available(PID__SET_TREASURY, "SET_TREASURY");
        emit Events.Sense_PermissionId_Available(PID__SET_PAYMASTER, "SET_PAYMASTER");
        emit Events.Sense_PermissionId_Available(PID__SET_EXTRA_DATA, "SET_EXTRA_DATA");
        emit Events.Sense_PermissionId_Available(PID__SET_METADATA, "SET_METADATA");
        emit Events.Sense_PermissionId_Available(PID__SET_SOURCE_STAMP_VERIFICATION, "SET_SOURCE_STAMP_VERIFICATION");
    }

    function _validateSource(SourceStamp calldata sourceStamp) internal virtual override {
        // If source stamp verification is disabled, we don't need to verify the source stamp
        if (Core.$storage().sourceStampVerificationEnabled) {
            super._validateSource(sourceStamp);
        }
    }

    function _isValidSourceStampSigner(address signer) internal virtual override returns (bool) {
        // Owner is not by default a signer, should be explicitly enabled as it.
        return Core.$storage().signerStorageHelper[signer].isSet;
    }

    function _setSourceStampVerification(bool isEnabled) internal virtual {
        Core.$storage().sourceStampVerificationEnabled = isEnabled;
        emit Sense_App_SourceStampVerificationSet(isEnabled);
    }

    function setSourceStampVerification(bool isEnabled) external virtual override {
        _requireAccess(msg.sender, PID__SET_SOURCE_STAMP_VERIFICATION);
        _setSourceStampVerification(isEnabled);
    }

    ///////////////// Graph

    function setGraph(address graph) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _setGraph(graph);
    }

    // In this implementation we allow to have a single graph only.
    function _setGraph(address graph) internal {
        address graphPreviouslySet = Core.$storage().defaultGraph;
        if (graphPreviouslySet != address(0)) {
            Core._removeGraph(graphPreviouslySet);
            emit Sense_App_GraphRemoved(graphPreviouslySet);
        }
        if (graph != address(0)) {
            emit Sense_App_GraphAdded(graph);
            Core._addGraph(graph);
        }
        Core._setDefaultGraph(graph);
    }

    ///////////////// Feed

    function addFeeds(address[] memory feeds) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _addFeeds(feeds);
    }

    function removeFeeds(address[] memory feeds) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _removeFeeds(feeds);
    }

    function setDefaultFeed(address feed) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        if (feed != address(0) && !Core._isFeedPresent(feed)) {
            Core._addFeed(feed);
            emit Sense_App_FeedAdded(feed);
        }
        _setDefaultFeed(feed);
    }

    function _addFeeds(address[] memory feeds) internal {
        for (uint256 i = 0; i < feeds.length; i++) {
            Core._addFeed(feeds[i]);
            emit Sense_App_FeedAdded(feeds[i]);
        }
    }

    function _removeFeeds(address[] memory feeds) internal {
        address defaultFeed = Core.$storage().defaultFeed;
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i] == defaultFeed) {
                _setDefaultFeed(address(0));
            }
            Core._removeFeed(feeds[i]);
            emit Sense_App_FeedRemoved(feeds[i]);
        }
    }

    function _setDefaultFeed(address feed) internal {
        Core._setDefaultFeed(feed);
        emit Sense_App_DefaultFeedSet(feed);
    }

    ///////////////// Namespace

    function setNamespace(address namespace) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _setNamespace(namespace);
    }

    // In this implementation we allow to have a single graph only.
    function _setNamespace(address namespace) internal {
        address namespacePreviouslySet = Core.$storage().defaultNamespace;
        if (namespacePreviouslySet != address(0)) {
            Core._removeNamespace(namespacePreviouslySet);
            emit Sense_App_NamespaceRemoved(namespacePreviouslySet);
        }
        if (namespace != address(0)) {
            emit Sense_App_NamespaceAdded(namespace);
            Core._addNamespace(namespace);
        }
        Core._setDefaultNamespace(namespace);
    }

    ///////////////// Group

    function setDefaultGroup(address group) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        if (group != address(0) && !Core._isGroupPresent(group)) {
            Core._addGroup(group);
            emit Sense_App_GroupAdded(group);
        }
        _setDefaultGroup(group);
    }

    function addGroups(address[] memory groups) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _addGroups(groups);
    }

    function removeGroups(address[] memory groups) external override {
        _requireAccess(msg.sender, PID__SET_PRIMITIVES);
        _removeGroups(groups);
    }

    function _addGroups(address[] memory groups) internal {
        for (uint256 i = 0; i < groups.length; i++) {
            Core._addGroup(groups[i]);
            emit Sense_App_GroupAdded(groups[i]);
        }
    }

    function _removeGroups(address[] memory groups) internal {
        address defaultGroup = Core.$storage().defaultGroup;
        for (uint256 i = 0; i < groups.length; i++) {
            if (groups[i] == defaultGroup) {
                _setDefaultGroup(address(0));
            }
            Core._removeGroup(groups[i]);
            emit Sense_App_GroupRemoved(groups[i]);
        }
    }

    function _setDefaultGroup(address group) internal {
        Core._setDefaultGroup(group);
        emit Sense_App_DefaultGroupSet(group);
    }

    ///////////////// Signers

    function addSigners(address[] memory signers) external {
        _requireAccess(msg.sender, PID__SET_SIGNERS);
        _addSigners(signers);
    }

    function removeSigners(address[] memory signers) external {
        _requireAccess(msg.sender, PID__SET_SIGNERS);
        _removeSigners(signers);
    }

    function _addSigners(address[] memory signers) internal {
        for (uint256 i = 0; i < signers.length; i++) {
            Core._addSigner(signers[i]);
            emit Sense_App_SignerAdded(signers[i]);
        }
    }

    function _removeSigners(address[] memory signers) internal {
        for (uint256 i = 0; i < signers.length; i++) {
            Core._removeSigner(signers[i]);
            emit Sense_App_SignerRemoved(signers[i]);
        }
    }

    ///////////////// Paymaster

    function setPaymaster(address paymaster) external override {
        _requireAccess(msg.sender, PID__SET_PAYMASTER);
        _setPaymaster(paymaster);
    }

    // In this implementation we allow to have a single paymaster only.
    function _setPaymaster(address paymaster) internal {
        address paymasterPreviouslySet = Core.$storage().defaultPaymaster;
        if (paymasterPreviouslySet != address(0)) {
            Core._removePaymaster(paymasterPreviouslySet);
            emit Sense_App_PaymasterRemoved(paymasterPreviouslySet);
        }
        if (paymaster != address(0)) {
            emit Sense_App_PaymasterAdded(paymaster);
            Core._addPaymaster(paymaster);
        }
        Core._setDefaultPaymaster(paymaster);
    }

    function getPaymaster() external view override returns (address) {
        return Core.$storage().defaultPaymaster;
    }

    ///////////////// Treasury

    function setTreasury(address treasury) external override {
        _requireAccess(msg.sender, PID__SET_TREASURY);
        _setTreasury(treasury);
    }

    function _setTreasury(address treasury) internal {
        Core._setTreasury(treasury);
        emit Sense_App_TreasurySet(treasury);
    }

    function getTreasury() external view override(IApp, ISource) returns (address) {
        return Core.$storage().treasury;
    }

    ///////////////// Metadata URI

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Sense_App_MetadataURISet(metadataURI);
    }

    ///////////////// Extra Data

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Sense_App_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Sense_App_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Sense_App_ExtraDataRemoved(extraDataRemoved.key);
    }

    //////////////////////////////////////////////////////////////////////////
    // Getters
    //////////////////////////////////////////////////////////////////////////

    function getGraphs() external view override returns (address[] memory) {
        return Core.$storage().graphs;
    }

    function getFeeds() external view override returns (address[] memory) {
        return Core.$storage().feeds;
    }

    function getNamespaces() external view override returns (address[] memory) {
        return Core.$storage().namespaces;
    }

    function getGroups() external view override returns (address[] memory) {
        return Core.$storage().groups;
    }

    function getDefaultGraph() external view override returns (address) {
        return Core.$storage().defaultGraph;
    }

    function getDefaultFeed() external view override returns (address) {
        return Core.$storage().defaultFeed;
    }

    function getDefaultNamespace() external view override returns (address) {
        return Core.$storage().defaultNamespace;
    }

    function getDefaultGroup() external view override returns (address) {
        return Core.$storage().defaultGroup;
    }

    function getDefaultPaymaster() external view override returns (address) {
        return Core.$storage().defaultPaymaster;
    }

    function getSigners() external view override returns (address[] memory) {
        return Core.$storage().signers;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }
}
