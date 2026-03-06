// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Membership, IGroup} from "contracts/core/interfaces/IGroup.sol";
import {GroupCore as Core} from "contracts/core/primitives/group/GroupCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedGroup} from "contracts/core/primitives/group/RuleBasedGroup.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {IAccountGroupAdditionSettings} from "contracts/core/interfaces/IAccountGroupAdditionSettings.sol";
import {KeyValueLib} from "contracts/core/libraries/KeyValueLib.sol";

// Resource IDs involved in the contract
/// @custom:keccak sense.permission.SetMetadata
uint256 constant PID__SET_METADATA = uint256(0xc593734a442ec90a714cfb87bfb7aca283b763335df63d0001196ab1ff115f53);
/// @custom:keccak sense.permission.ChangeRules
uint256 constant PID__CHANGE_RULES = uint256(0xde011e4a0a5ba313b0ac8a7e2b9d7ee3156d91c77a234d9be7f9ed14184deaec);
/// @custom:keccak sense.permission.SetExtraData
uint256 constant PID__SET_EXTRA_DATA = uint256(0x89230884684683d91d892d3bd0c063380fe312b990f4c455be670b9b5b0c30c2);
/// @custom:keccak sense.permission.AddMember
uint256 constant PID__ADD_MEMBER = uint256(0x7975da81c3eb15a487a022674de548c87768be7c96c68d8f8560ea96b553a09c);
/// @custom:keccak sense.permission.RemoveMember
uint256 constant PID__REMOVE_MEMBER = uint256(0xdd20b5712d56709059ba6d5be4805add03a675fa6ffe2d8d6cb116b14fa6101f);
/// @custom:keccak sense.permission.SkipAddMemberRules
uint256 constant PID__SKIP_ADD_MEMBER_RULES = uint256(0x3aa52594fa508d1db0c0dfe361541bed5b12d178b184c9afaaaeeebbee9b600a);
/// @custom:keccak sense.permission.SkipRemoveMemberRules
uint256 constant PID__SKIP_REMOVE_MEMBER_RULES =
    uint256(0x4d3a597e22a7dbca3e78ef71512f62ef71fa71bdeb4e81b73ba77f11a1db5f37);

/// @custom:keccak sense.param.accountAdditionSettingsParams
bytes32 constant PARAM__ACCOUNT_ADDITION_SETTINGS_PARAMS =
    0x94e635d0c6ead24a1112c887c590f1a6d3fdaf31729c32af83aeffeaea89d21e;

contract Group is
    IGroup,
    Initializable,
    RuleBasedGroup,
    AccessControlled,
    ExtraDataBased,
    SourceStampBased,
    MetadataBased
{
    using KeyValueLib for KeyValue[];

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory metadataURI, IAccessControl accessControl, address foundingMember)
        external
        override
        initializer
    {
        _initialize(metadataURI, foundingMember);
        AccessControlled._initialize(accessControl);
    }

    function _initialize(string memory metadataURI, address foundingMember) internal {
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Sense_Contract_Deployed({contractType: "sense.contract.Group", flavour: "sense.contract.Group"});
        if (foundingMember != address(0)) {
            emit Sense_Group_MemberAdded(
                foundingMember,
                Core._grantMembership(foundingMember),
                new KeyValue[](0),
                new RuleProcessingParams[](0),
                address(0)
            );
        }
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Sense_Group_MetadataURISet(metadataURI);
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

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory ruleChanges)
        internal
        pure
        virtual
        override
    {}

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Sense_Group_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Sense_Group_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Sense_Group_ExtraDataRemoved(extraDataRemoved.key);
    }

    // Public functions

    function addMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external payable override usingNativePaymentHelper {
        _addMember(account, customParams, ruleProcessingParams, _processSourceStamp(customParams));
    }

    function removeMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external payable override usingNativePaymentHelper {
        _removeMember(account, customParams, ruleProcessingParams, _processSourceStamp(customParams));
    }

    function joinGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external payable override usingNativePaymentHelper {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 membershipId = Core._grantMembership(account);
        _processMemberJoining(msg.sender, account, customParams, ruleProcessingParams);
        address source = _processSourceStamp(membershipId, customParams);
        emit Sense_Group_MemberJoined(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function leaveGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external payable override usingNativePaymentHelper {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 membershipId = Core._revokeMembership(account);
        _processMemberLeaving(msg.sender, account, customParams, ruleProcessingParams);
        address source = _processSourceStamp(customParams);
        _clearSource(membershipId);
        emit Sense_Group_MemberLeft(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _addMember(
        address account,
        KeyValue[] memory customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal {
        uint256 membershipId = Core._grantMembership(account);
        _processMemberAddition(msg.sender, account, customParams, ruleProcessingParams);
        // We require accounts to allow being added to the group; EOAs are expected to fail under this condition.
        require(
            IAccountGroupAdditionSettings(account).canBeAddedToGroup({
                group: address(this),
                addedBy: msg.sender,
                params: _extractAccountAdditionSettingsParamsFromParams(customParams)
            }),
            Errors.NotAllowed()
        );
        _storeSource(membershipId, source);
        emit Sense_Group_MemberAdded(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function _removeMember(
        address account,
        KeyValue[] memory customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal {
        uint256 membershipId = Core._revokeMembership(account);
        _processMemberRemoval(msg.sender, account, customParams, ruleProcessingParams);
        _clearSource(membershipId);
        emit Sense_Group_MemberRemoved(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function _extractAccountAdditionSettingsParamsFromParams(KeyValue[] memory customParams)
        internal
        pure
        returns (KeyValue[] memory)
    {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__ACCOUNT_ADDITION_SETTINGS_PARAMS) {
                return abi.decode(customParams[i].value, (KeyValue[]));
            }
        }
        return new KeyValue[](0);
    }

    // Batch operations

    struct MemberBatchParams {
        address account;
        KeyValue[] customParams;
        RuleProcessingParams[] ruleProcessingParams;
    }

    function addMembers(MemberBatchParams[] calldata membersToAdd, KeyValue[] calldata customParams) external {
        address source = _processSourceStamp(customParams);
        for (uint256 i = 0; i < membersToAdd.length; i++) {
            _addMember(
                membersToAdd[i].account,
                customParams.concat(membersToAdd[i].customParams),
                membersToAdd[i].ruleProcessingParams,
                source
            );
        }
    }

    function removeMembers(MemberBatchParams[] calldata membersToRemove, KeyValue[] calldata customParams) external {
        address source = _processSourceStamp(customParams);
        for (uint256 i = 0; i < membersToRemove.length; i++) {
            _removeMember(
                membersToRemove[i].account,
                customParams.concat(membersToRemove[i].customParams),
                membersToRemove[i].ruleProcessingParams,
                source
            );
        }
    }

    // Getters

    function getNumberOfMembers() external view override returns (uint256) {
        return Core.$storage().numberOfMembers;
    }

    function isMember(address account) external view override returns (bool) {
        return Core._isMember(account);
    }

    function getMembership(address account) external view override returns (Membership memory) {
        Membership memory membership = Core._getMembership(account);
        require(membership.id != 0, Errors.DoesNotExist());
        return membership;
    }

    function getMembershipTimestamp(address account) external view override returns (uint256) {
        Membership memory membership = Core._getMembership(account);
        require(membership.id != 0, Errors.DoesNotExist());
        return membership.timestamp;
    }

    function getMembershipId(address account) external view override returns (uint256) {
        uint256 membershipId = Core.$storage().memberships[account].id;
        require(membershipId != 0, Errors.DoesNotExist());
        return membershipId;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function getMembershipSource(uint256 membershipId) external view override returns (address) {
        return _getSource(membershipId);
    }
}
