// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Follow, IGraph} from "contracts/core/interfaces/IGraph.sol";
import {GraphCore as Core} from "contracts/core/primitives/graph/GraphCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedGraph} from "contracts/core/primitives/graph/RuleBasedGraph.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract Graph is
    IGraph,
    Initializable,
    RuleBasedGraph,
    AccessControlled,
    ExtraDataBased,
    SourceStampBased,
    MetadataBased
{
    // Resource IDs involved in the contract

    /// @custom:keccak sense.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0xde011e4a0a5ba313b0ac8a7e2b9d7ee3156d91c77a234d9be7f9ed14184deaec);
    /// @custom:keccak sense.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xc593734a442ec90a714cfb87bfb7aca283b763335df63d0001196ab1ff115f53);
    /// @custom:keccak sense.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x89230884684683d91d892d3bd0c063380fe312b990f4c455be670b9b5b0c30c2);

    /// @custom:keccak sense.entityType.Follow
    bytes32 constant ENTITY_TYPE__FOLLOW = 0x5e809f0654bd4585e0be718855e409ee378c64ed6d09db1cdf71b49cb7f6143d;

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory metadataURI, IAccessControl accessControl) external override initializer {
        _initialize(metadataURI);
        AccessControlled._initialize(accessControl);
    }

    function _initialize(string memory metadataURI) internal {
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Sense_Contract_Deployed({contractType: "sense.contract.Graph", flavour: "sense.contract.Graph"});
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Sense_Graph_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Sense_PermissionId_Available(PID__CHANGE_RULES, "sense.permission.ChangeRules");
        emit Events.Sense_PermissionId_Available(PID__SET_METADATA, "sense.permission.SetMetadata");
        emit Events.Sense_PermissionId_Available(PID__SET_EXTRA_DATA, "sense.permission.SetExtraData");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeChangePrimitiveRules(RuleChange[] memory /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory /* ruleChanges */ )
        internal
        virtual
        override
    {
        require(msg.sender == address(uint160(entityId)), Errors.InvalidMsgSender()); // Follow rules can only be changed in your own account
    }

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Sense_Graph_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Sense_Graph_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Sense_Graph_ExtraDataRemoved(extraDataRemoved.key);
    }

    // Public functions

    function follow(
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams,
        KeyValue[] calldata extraData
    ) external payable virtual override usingNativePaymentHelper returns (uint256) {
        require(msg.sender == followerAccount, Errors.InvalidMsgSender());
        // If some implementation wants to allow followId specification, it can be implemented using customParams.
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, 0, block.timestamp);
        address source = _processSourceStamp(_getFollowEntityType(accountToFollow), assignedFollowId, customParams);
        _graphProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, graphRulesProcessingParams);
        _accountProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, followRulesProcessingParams);
        emit Sense_Graph_Followed(
            followerAccount,
            accountToFollow,
            assignedFollowId,
            customParams,
            graphRulesProcessingParams,
            followRulesProcessingParams,
            source,
            extraData
        );
        return assignedFollowId;
    }

    function unfollow(
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external payable virtual override usingNativePaymentHelper returns (uint256) {
        require(msg.sender == followerAccount, Errors.InvalidMsgSender());
        uint256 followId = Core._unfollow(followerAccount, accountToUnfollow);
        address source = _processSourceStamp(customParams);
        _graphProcessUnfollow(msg.sender, followerAccount, accountToUnfollow, customParams, graphRulesProcessingParams);
        /**
         * Clears follow source when unfollowing. A Graph primitive implementation that tokenizes follows might want to
         * store an additional DATA__CREATION_SOURCE for when the first follow, which minted the token, was done, and
         * keep it until the follow token is burnt.
         */
        _clearSource(_getFollowEntityType(accountToUnfollow), followId);
        emit Sense_Graph_Unfollowed(
            followerAccount, accountToUnfollow, followId, customParams, graphRulesProcessingParams, source
        );
        return followId;
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _getFollowEntityType(address targetAccount) internal pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(ENTITY_TYPE__FOLLOW, targetAccount)));
    }

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view override returns (bool) {
        return Core.$storage().follows[followerAccount][targetAccount].id != 0;
    }

    function getFollowerById(address account, uint256 followId) external view override returns (address) {
        address follower = Core.$storage().followers[account][followId];
        require(follower != address(0), Errors.DoesNotExist());
        return follower;
    }

    function getFollow(address followerAccount, address targetAccount) external view override returns (Follow memory) {
        Follow memory followData = Core.$storage().follows[followerAccount][targetAccount];
        require(followData.id != 0, Errors.DoesNotExist());
        return followData;
    }

    function getFollowersCount(address account) external view override returns (uint256) {
        return Core.$storage().followersCount[account];
    }

    function getFollowingCount(address account) external view override returns (uint256) {
        return Core.$storage().followingCount[account];
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function getFollowSource(address followedAccount, uint256 followId) external view override returns (address) {
        return _getSource(_getFollowEntityType(followedAccount), followId);
    }
}
