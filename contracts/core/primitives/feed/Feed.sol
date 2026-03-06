// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IFeed, Post, EditPostParams, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";
import {FeedCore as Core} from "contracts/core/primitives/feed/FeedCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleBasedFeed} from "contracts/core/primitives/feed/RuleBasedFeed.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {EntityExtraDataBased} from "contracts/core/base/EntityExtraDataBased.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract Feed is
    IFeed,
    Initializable,
    RuleBasedFeed,
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
    /// @custom:keccak sense.permission.RemovePost
    uint256 constant PID__REMOVE_POST = uint256(0xc550c6daf63a72b671ddce6cc124c13d6054506fa1b55f01af4b651d88a571d0);

    /// @custom:keccak sense.param.expectedPostId
    bytes32 constant PARAM__EXPECTED_POST_ID = 0x06ce7f74bdd55ae3240a09e41459945bc6abad800dc41253e4d177a0f225fbec;

    /// @custom:keccak sense.data.lastUpdatedSource
    bytes32 constant DATA__LAST_UPDATED_SOURCE = 0x96b63a0919b79e32de4dc35ca188d24e828195655ec7b68e412fb3984a894db8;

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
        emit Events.Sense_Contract_Deployed({contractType: "sense.contract.Feed", flavour: "sense.contract.Feed"});
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Sense_Feed_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Sense_PermissionId_Available(PID__CHANGE_RULES, "sense.permission.ChangeRules");
        emit Events.Sense_PermissionId_Available(PID__SET_METADATA, "sense.permission.SetMetadata");
        emit Events.Sense_PermissionId_Available(PID__SET_EXTRA_DATA, "sense.permission.SetExtraData");
        emit Events.Sense_PermissionId_Available(PID__REMOVE_POST, "sense.permission.RemovePost");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view virtual override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeChangePrimitiveRules(RuleChange[] memory /* ruleChanges */ ) internal view virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory /* ruleChanges */ )
        internal
        view
        virtual
        override
    {
        require(Core._postExists(entityId), Errors.DoesNotExist());
        require(msg.sender == Core.$storage().posts[entityId].author, Errors.InvalidMsgSender());
        require(entityId == Core.$storage().posts[entityId].rootPostId, Errors.CannotHaveRules());
    }

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Sense_Feed_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Sense_Feed_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Sense_Feed_ExtraDataRemoved(extraDataRemoved.key);
    }

    function _emitEntityExtraDataAddedEvent(uint256 postId, KeyValue memory extraDataAdded) internal override {
        emit Sense_Feed_Post_ExtraDataAdded(postId, extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitEntityExtraDataUpdatedEvent(uint256 postId, KeyValue memory extraDataUpdated) internal override {
        emit Sense_Feed_Post_ExtraDataUpdated(
            postId, extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value
        );
    }

    function _emitEntityExtraDataRemovedEvent(uint256 postId, KeyValue memory extraDataRemoved) internal override {
        emit Sense_Feed_Post_ExtraDataRemoved(postId, extraDataRemoved.key);
    }

    // Public user functions

    function createPost(
        CreatePostParams memory postParams,
        KeyValue[] memory customParams,
        RuleProcessingParams[] memory feedRulesParams,
        RuleProcessingParams[] memory rootPostRulesParams,
        RuleProcessingParams[] memory quotedPostRulesParams
    ) external payable virtual override usingNativePaymentHelper returns (uint256) {
        require(msg.sender == postParams.author, Errors.InvalidMsgSender());
        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) = Core._createPost(postParams);
        _validateExpectedPostIdIfPresent(customParams, postId);
        address source = _processSourceStamp(postId, customParams);
        _storeSource(DATA__LAST_UPDATED_SOURCE, postId, source);
        _processPostCreationOnFeed(postId, postParams, customParams, feedRulesParams);
        // Process rules of the Quote (if quoting)
        if (postParams.quotedPostId != 0) {
            // Existence of the quotedPost post was checked in the Core
            // Just a thought: Maybe quotes shouldn't be limited by rules... Like quotations in real life.
            uint256 rootOfQuotedPost = Core.$storage().posts[postParams.quotedPostId].rootPostId;
            if (rootOfQuotedPost != rootPostId && Core._postExists(rootOfQuotedPost)) {
                _processPostCreationOnRootPost(rootOfQuotedPost, postId, postParams, customParams, quotedPostRulesParams);
            }
        }
        if (postId != rootPostId) {
            // Existence of the Replied/Reposted Post is checked in the Core
            require(postParams.ruleChanges.length == 0, Errors.CannotHaveRules());
            if (Core._postExists(rootPostId)) {
                // This covers the Reply or Repost cases
                _processPostCreationOnRootPost(rootPostId, postId, postParams, customParams, rootPostRulesParams);
            }
        } else {
            _addPostRulesAtCreation(postId, postParams, feedRulesParams);
        }
        emit Sense_Feed_PostCreated(
            postId,
            postParams.author,
            localSequentialId,
            rootPostId,
            postParams,
            customParams,
            feedRulesParams,
            rootPostRulesParams,
            quotedPostRulesParams,
            source
        );
        _setEntityExtraData(postId, postParams.extraData);
        return postId;
    }

    function editPost(
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] memory customParams,
        RuleProcessingParams[] memory feedRulesParams,
        RuleProcessingParams[] memory rootPostRulesParams,
        RuleProcessingParams[] memory quotedPostRulesParams
    ) external payable virtual override usingNativePaymentHelper {
        require(Core._postExists(postId), Errors.DoesNotExist());
        address author = Core.$storage().posts[postId].author;
        // You can have this if you want to allow moderator editing:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_PID));
        require(msg.sender == author, Errors.InvalidMsgSender());
        Core._editPost(postId, postParams);
        _setEntityExtraData(postId, postParams.extraData);
        _processPostEditingOnFeed(postId, postParams, customParams, feedRulesParams);
        uint256 quotedPostId = Core.$storage().posts[postId].quotedPostId;
        if (quotedPostId != 0) {
            uint256 rootOfQuotedPost = Core.$storage().posts[quotedPostId].rootPostId;
            // Skip the Root rules processing if the Root post was deleted
            if (Core._postExists(rootOfQuotedPost)) {
                _processPostEditingOnRootPost(rootOfQuotedPost, postId, postParams, customParams, quotedPostRulesParams);
            }
        }
        uint256 rootPostId = Core.$storage().posts[postId].rootPostId;
        // Skip the Root rules processing if the Root post was deleted
        if (postId != rootPostId && Core._postExists(rootPostId)) {
            _processPostEditingOnRootPost(rootPostId, postId, postParams, customParams, rootPostRulesParams);
        }
        address source = _processSourceStamp(DATA__LAST_UPDATED_SOURCE, postId, customParams);
        emit Sense_Feed_PostEdited(
            postId, author, postParams, customParams, feedRulesParams, rootPostRulesParams, quotedPostRulesParams, source
        );
    }

    function deletePost(
        uint256 postId,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) external payable virtual override usingNativePaymentHelper {
        require(Core._postExists(postId), Errors.DoesNotExist());
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, PID__REMOVE_POST), Errors.InvalidMsgSender());
        Core._removePost(postId);
        _processPostDeletion(postId, customParams, feedRulesParams);
        address source = _processSourceStamp(DATA__LAST_UPDATED_SOURCE, postId, customParams);
        emit Sense_Feed_PostDeleted(postId, author, customParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    // Getters

    function getPost(uint256 postId) external view override returns (Post memory) {
        require(Core._postExists(postId), Errors.DoesNotExist());
        return _getPostUnchecked(postId);
    }

    function getPostUnchecked(uint256 postId) external view override returns (Post memory) {
        return _getPostUnchecked(postId);
    }

    function _getPostUnchecked(uint256 postId) internal view returns (Post memory) {
        return Post({
            author: Core.$storage().posts[postId].author,
            authorPostSequentialId: Core.$storage().posts[postId].authorPostSequentialId,
            postSequentialId: Core.$storage().posts[postId].postSequentialId,
            contentURI: Core.$storage().posts[postId].contentURI,
            rootPostId: Core.$storage().posts[postId].rootPostId,
            repostedPostId: Core.$storage().posts[postId].repostedPostId,
            quotedPostId: Core.$storage().posts[postId].quotedPostId,
            repliedPostId: Core.$storage().posts[postId].repliedPostId,
            creationTimestamp: Core.$storage().posts[postId].creationTimestamp,
            creationSource: _getSource(postId),
            lastUpdatedTimestamp: Core.$storage().posts[postId].lastUpdatedTimestamp,
            lastUpdateSource: _getSource(DATA__LAST_UPDATED_SOURCE, postId),
            isDeleted: Core.$storage().posts[postId].isDeleted
        });
    }

    function postExists(uint256 postId) external view override returns (bool) {
        return Core._postExists(postId);
    }

    function getPostAuthor(uint256 postId) external view override returns (address) {
        require(Core._postExists(postId), Errors.DoesNotExist());
        return Core.$storage().posts[postId].author;
    }

    function getPostCount() external view override returns (uint256) {
        return Core.$storage().postCount;
    }

    function getPostCount(address author) external view override returns (uint256) {
        return Core.$storage().authorPostCount[author];
    }

    function getPostExtraData(uint256 postId, bytes32 key) external view override returns (bytes memory) {
        require(Core._postExists(postId), Errors.DoesNotExist());
        address postAuthor = Core.$storage().posts[postId].author;
        return _getEntityExtraStorage_Account(postAuthor, postId, key);
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function getPostSequentialId(uint256 postId) external view override returns (uint256) {
        require(Core._postExists(postId), Errors.DoesNotExist());
        return Core.$storage().posts[postId].postSequentialId;
    }

    function getAuthorPostSequentialId(uint256 postId) external view override returns (uint256) {
        require(Core._postExists(postId), Errors.DoesNotExist());
        return Core.$storage().posts[postId].authorPostSequentialId;
    }

    function getNextPostId(address author) external view returns (uint256) {
        return Core._generatePostId(author, Core.$storage().authorPostCount[author] + 1);
    }

    function _validateExpectedPostIdIfPresent(KeyValue[] memory customParams, uint256 postId) internal pure {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__EXPECTED_POST_ID) {
                require(postId == abi.decode(customParams[i].value, (uint256)), Errors.UnexpectedValue());
                return;
            }
        }
    }
}
