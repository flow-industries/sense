// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {NamespaceCore as Core} from "contracts/core/primitives/namespace/NamespaceCore.sol";
import {IERC721Namespace} from "contracts/core/interfaces/IERC721Namespace.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedNamespace} from "contracts/core/primitives/namespace/RuleBasedNamespace.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {EntityExtraDataBased} from "contracts/core/base/EntityExtraDataBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SenseERC721} from "contracts/core/base/SenseERC721.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";
import {IAccessControlled} from "contracts/core/interfaces/IAccessControlled.sol";

contract Namespace is
    IERC721Namespace,
    Initializable,
    SenseERC721,
    RuleBasedNamespace,
    AccessControlled,
    ExtraDataBased,
    EntityExtraDataBased,
    SourceStampBased,
    MetadataBased
{
    /// @custom:keccak sense.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xc593734a442ec90a714cfb87bfb7aca283b763335df63d0001196ab1ff115f53);
    /// @custom:keccak sense.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0xde011e4a0a5ba313b0ac8a7e2b9d7ee3156d91c77a234d9be7f9ed14184deaec);
    /// @custom:keccak sense.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x89230884684683d91d892d3bd0c063380fe312b990f4c455be670b9b5b0c30c2);
    /// @custom:keccak sense.permission.SetTokenURIProvider
    uint256 constant PID__SET_TOKEN_URI_PROVIDER =
        uint256(0xcacfcd5128751f553d1935f7feaf5141d13b4de459f17a8072d672c221973952);
    /// @custom:keccak sense.permission.AssignUsername
    uint256 constant PID__ASSIGN_USERNAME = uint256(0x3c87a82b30f2bbd8c7aea56ab1a2e859419f6176cf30c57b6b50b837fcb638c2);

    /// @custom:keccak sense.data.assignmentSource
    bytes32 constant DATA__ASSIGNMENT_SOURCE = 0x1b8675dd23b5c60cf325498b1fb2cee5604e8330e499b892318cd5733f55dc99;

    /// @custom:keccak sense.storage.Namespace
    uint256 constant STORAGE__NAMESPACE = 0x4b166fa2a217e314ef91eccd82e999160007372f58336bd2d6a6733f74297730;

    struct NamespaceStorage {
        mapping(uint256 => string) idToUsername;
    }

    function $storage() internal pure returns (NamespaceStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__NAMESPACE
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory namespace,
        string memory metadataURI,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider,
        IAccessControl accessControl
    ) external override initializer {
        _initialize(namespace, metadataURI);
        AccessControlled._initialize(accessControl);
        SenseERC721._initialize(nftName, nftSymbol, tokenURIProvider);
    }

    function _initialize(string memory namespace, string memory metadataURI) internal {
        Core.$storage().namespace = namespace;
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Sense_Contract_Deployed({
            contractType: "sense.contract.Namespace",
            flavour: "sense.contract.Namespace.ERC721Namespace"
        });
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Sense_Namespace_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Sense_PermissionId_Available(PID__CHANGE_RULES, "sense.permission.ChangeRules");
        emit Events.Sense_PermissionId_Available(PID__SET_METADATA, "sense.permission.SetMetadata");
        emit Events.Sense_PermissionId_Available(PID__SET_EXTRA_DATA, "sense.permission.SetExtraData");
        emit Events.Sense_PermissionId_Available(PID__SET_TOKEN_URI_PROVIDER, "sense.permission.SetTokenURIProvider");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeTokenURIProviderSet(ITokenURIProvider /* tokenURIProvider */ ) internal view virtual override {
        _requireAccess(msg.sender, PID__SET_TOKEN_URI_PROVIDER);
    }

    function _beforeChangePrimitiveRules(RuleChange[] memory /* ruleChanges */ ) internal view virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory ruleChanges)
        internal
        pure
        virtual
        override
    {}

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Sense_Namespace_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Sense_Namespace_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Sense_Namespace_ExtraDataRemoved(extraDataRemoved.key);
    }

    function _emitEntityExtraDataAddedEvent(uint256 usernameId, KeyValue memory extraDataAdded) internal override {
        emit Sense_Username_ExtraDataAdded(usernameId, extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitEntityExtraDataUpdatedEvent(uint256 usernameId, KeyValue memory extraDataUpdated) internal override {
        emit Sense_Username_ExtraDataUpdated(
            usernameId, extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value
        );
    }

    function _emitEntityExtraDataRemovedEvent(uint256 usernameId, KeyValue memory extraDataRemoved) internal override {
        emit Sense_Username_ExtraDataRemoved(usernameId, extraDataRemoved.key);
    }

    // Permissionless functions

    function createAndAssignUsername(
        address account,
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningProcessingParams,
        RuleProcessingParams[] calldata creationProcessingParams,
        RuleProcessingParams[] calldata assigningProcessingParams,
        KeyValue[] memory extraData
    ) external payable usingNativePaymentHelper {
        require(msg.sender == account || _doesMsgSenderControlAccount(account), Errors.InvalidMsgSender());
        uint256 id = _computeId(username);
        _safeMint(account, id);
        $storage().idToUsername[id] = username;
        Core._createUsername(username);
        address source = _processSourceStamp(id, customParams);
        _setEntityExtraData(id, extraData);
        emit Sense_Username_Created(username, account, customParams, creationProcessingParams, source, extraData);
        _unassignIfAssigned(account, customParams, unassigningProcessingParams, source);
        Core._assignUsername(account, username);
        _storeSource(DATA__ASSIGNMENT_SOURCE, id, source); // Stores after unassign, as unassign could clear the source
        emit Sense_Username_Assigned(username, account, customParams, assigningProcessingParams, source);
        _processCreation(msg.sender, account, username, customParams, creationProcessingParams);
        _processAssigning(msg.sender, account, username, customParams, assigningProcessingParams);
    }

    function createUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        KeyValue[] calldata extraData
    ) external payable override usingNativePaymentHelper {
        uint256 id = _computeId(username);
        _safeMint(account, id);
        $storage().idToUsername[id] = username;
        Core._createUsername(username);
        address source = _processSourceStamp(id, customParams);
        _processCreation(msg.sender, account, username, customParams, ruleProcessingParams);
        _setEntityExtraData(id, extraData);
        emit Sense_Username_Created(username, account, customParams, ruleProcessingParams, source, extraData);
    }

    function removeUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningRuleProcessingParams,
        RuleProcessingParams[] calldata removalRuleProcessingParams
    ) external payable override usingNativePaymentHelper {
        uint256 id = _computeId(username);
        address owner = ownerOf(id);
        require(msg.sender == owner, Errors.InvalidMsgSender()); // msg.sender must be the owner of the username
        address source = _processSourceStamp(customParams);
        _processRemoval(msg.sender, username, customParams, removalRuleProcessingParams);
        _unassignIfAssigned(username, customParams, unassigningRuleProcessingParams, source); // Clears DATA__ASSIGNMENT_SOURCE
        _clearSource(id); // Clears DATA__SOURCE, which is the creation source
        _burn(id);
        Core._removeUsername(username);
        emit Sense_Username_Removed(username, owner, customParams, removalRuleProcessingParams, source);
    }

    function assignUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassignAccountRuleProcessingParams,
        RuleProcessingParams[] calldata unassignUsernameRuleProcessingParams,
        RuleProcessingParams[] calldata assignRuleProcessingParams
    ) external payable override usingNativePaymentHelper {
        uint256 id = _computeId(username);
        // msg.sender should own the tokenized username
        require(msg.sender == ownerOf(id), Errors.InvalidMsgSender());
        // msg.sender should either be the account or control the account
        require(msg.sender == account || _doesMsgSenderControlAccount(account), Errors.InvalidMsgSender());
        // Check if username is not already assigned to this account
        require(account != Core.$storage().usernameToAccount[username], Errors.RedundantStateChange());
        address source = _processSourceStamp(customParams);
        _unassignIfAssigned(account, customParams, unassignAccountRuleProcessingParams, source);
        _unassignIfAssigned(username, customParams, unassignUsernameRuleProcessingParams, source);
        _storeSource(DATA__ASSIGNMENT_SOURCE, id, source); // Stores after unassign, as unassign could clear the source
        Core._assignUsername(account, username);
        _processAssigning(msg.sender, account, username, customParams, assignRuleProcessingParams);
        emit Sense_Username_Assigned(username, account, customParams, assignRuleProcessingParams, source);
    }

    function _doesMsgSenderControlAccount(address account) internal view returns (bool) {
        try IOwnable(account).owner() returns (address accountOwner) {
            // Account is Ownable: checking if msg.sender is the owner
            if (msg.sender == accountOwner) {
                return true;
            }
        } catch {
            // Account is not ownable:
            // Do nothing, still needs to check if msg.sender has access through the access control.
        }

        try IAccessControlled(account).getAccessControl() returns (IAccessControl accountAccessControl) {
            // Account is AccessControlled: checking if msg.sender has access to assign username
            try accountAccessControl.hasAccess(msg.sender, address(this), PID__ASSIGN_USERNAME) returns (
                bool hasAccessToAssignUsername
            ) {
                // Account has AssignUsername permission
                return hasAccessToAssignUsername;
            } catch {
                // No access
                return false;
            }
        } catch {
            // Account is not ownable nor AccessControlled: no access
            return false;
        }
    }

    function unassignUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external payable override usingNativePaymentHelper {
        address account = Core.$storage().usernameToAccount[username];
        uint256 id = _computeId(username);
        require(msg.sender == ownerOf(id) || msg.sender == account, Errors.InvalidMsgSender());
        Core._unassignUsername(username);
        _processUnassigning(msg.sender, account, username, customParams, ruleProcessingParams);
        address source = _processSourceStamp(customParams);
        _clearSource(DATA__ASSIGNMENT_SOURCE, id);
        emit Sense_Username_Unassigned(username, account, customParams, ruleProcessingParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function setUsernameExtraData(string calldata username, KeyValue[] calldata extraDataToSet) external {
        uint256 id = _computeId(username);
        address owner = _ownerOf(id);
        require(msg.sender == owner, Errors.InvalidMsgSender());
        _setEntityExtraData(id, extraDataToSet);
    }

    // Internal

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        emit Sense_Username_Transfer(from, to, tokenId);
    }

    function _computeId(string memory username) internal pure virtual returns (uint256) {
        return uint256(keccak256(bytes(username)));
    }

    function _unassignIfAssigned(
        string memory username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal virtual {
        address assignedAccount = Core.$storage().usernameToAccount[username];
        if (assignedAccount != address(0)) {
            _clearSource(DATA__ASSIGNMENT_SOURCE, _computeId(username));
            Core._unassignUsername(username);
            _processUnassigning(msg.sender, assignedAccount, username, customParams, ruleProcessingParams);
            emit Sense_Username_Unassigned(username, assignedAccount, customParams, ruleProcessingParams, source);
        }
    }

    function _unassignIfAssigned(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal virtual {
        string memory assignedUsername = Core.$storage().accountToUsername[account];
        if (bytes(assignedUsername).length != 0) {
            _clearSource(DATA__ASSIGNMENT_SOURCE, _computeId(assignedUsername));
            Core._unassignUsername(assignedUsername);
            _processUnassigning(msg.sender, account, assignedUsername, customParams, ruleProcessingParams);
            emit Sense_Username_Unassigned(assignedUsername, account, customParams, ruleProcessingParams, source);
        }
    }

    // Getters

    function usernameOf(address user) external view returns (string memory) {
        string memory username = Core.$storage().accountToUsername[user];
        require(bytes(username).length != 0, Errors.DoesNotExist());
        return username;
    }

    // Assigned to
    function accountOf(string memory username) external view returns (address) {
        uint256 tokenId = _computeId(username);
        require(_exists(tokenId), Errors.DoesNotExist());
        return Core.$storage().usernameToAccount[username];
    }

    // Owner of the username
    function ownerOf(string memory username) external view returns (address) {
        uint256 tokenId = _computeId(username);
        require(_exists(tokenId), Errors.DoesNotExist());
        return _ownerOf(tokenId);
    }

    function getNamespace() external view returns (string memory) {
        return Core.$storage().namespace;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function getUsernameExtraData(string calldata username, bytes32 key) external view override returns (bytes memory) {
        uint256 tokenId = _computeId(username);
        address owner = ownerOf(tokenId);
        return _getEntityExtraData(owner, tokenId, key);
    }

    function exists(string calldata username) external view override returns (bool) {
        uint256 tokenId = _computeId(username);
        return _exists(tokenId);
    }

    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function getTokenIdByUsername(string calldata username) external pure override returns (uint256) {
        return _computeId(username);
    }

    function getUsernameByTokenId(uint256 tokenId) external view override returns (string memory) {
        require(_exists(tokenId), Errors.DoesNotExist());
        return $storage().idToUsername[tokenId];
    }

    function getUsernameCreationSource(string calldata username) external view returns (address) {
        return _getSource(_computeId(username));
    }

    function getUsernameAssignmentSource(string calldata username) external view override returns (address) {
        return _getSource(DATA__ASSIGNMENT_SOURCE, _computeId(username));
    }
}
