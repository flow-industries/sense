// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IPostRule} from "contracts/core/interfaces/IPostRule.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract FollowersOnlyPostRule is OwnableMetadataBasedRule, Initializable, IPostRule {
    /// @custom:keccak sense.param.graph
    bytes32 constant PARAM__GRAPH = 0x8575ce699158cf9c5056247d9d6a1a15a40d5cf266e79cdb75157cc07c83f5a3;
    /// @custom:keccak sense.param.repliesRestricted
    bytes32 constant PARAM__REPLIES_RESTRICTED = 0x23eac1188784468413bdf97e250704295c67776c2a06aa5476f1bf4c61022456;
    /// @custom:keccak sense.param.repostsRestricted
    bytes32 constant PARAM__REPOSTS_RESTRICTED = 0x7a03013eb54c247271463cc6b72fd462bb83563f6e5473563a7893cd3d01e4ab;
    /// @custom:keccak sense.param.quotesRestricted
    bytes32 constant PARAM__QUOTES_RESTRICTED = 0x6f899e4dcf7c634d266270d965ce42da1860bad227c45c862ae3e4640da657b0;

    /// @custom:keccak sense.storage.FollowersOnlyPostRule
    bytes32 constant STORAGE__FOLLOWERS_ONLY_POST_RULE =
        0xbf6aa7e0c78e0c7eb1eff7e10c7ab77cf28dfc0a53233a93dc09f905a02f3ea7;

    struct Configuration {
        address graph;
        bool repliesRestricted;
        bool repostsRestricted;
        bool quotesRestricted;
    }

    struct Storage {
        mapping(address feed => mapping(bytes32 configSalt => mapping(uint256 postId => Configuration config)))
            configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__FOLLOWERS_ONLY_POST_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, uint256 postId, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__GRAPH) {
                configuration.graph = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__REPLIES_RESTRICTED) {
                configuration.repliesRestricted = abi.decode(ruleParams[i].value, (bool));
            } else if (ruleParams[i].key == PARAM__REPOSTS_RESTRICTED) {
                configuration.repostsRestricted = abi.decode(ruleParams[i].value, (bool));
            } else if (ruleParams[i].key == PARAM__QUOTES_RESTRICTED) {
                configuration.quotesRestricted = abi.decode(ruleParams[i].value, (bool));
            }
        }
        IGraph(configuration.graph).isFollowing(address(this), msg.sender); // Verifies the provided address is a graph
        require(
            configuration.repliesRestricted || configuration.repostsRestricted || configuration.quotesRestricted,
            Errors.InvalidParameter()
        );
        $storage().configuration[msg.sender][configSalt][postId] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256 rootPostId,
        uint256 postId,
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt][rootPostId];
        if (_shouldRestrictionBeApplied(configuration, rootPostId, postParams)) {
            IFeed feed = IFeed(msg.sender);
            IGraph graph = IGraph(configuration.graph);
            address rootPostAuthor = feed.getPostAuthor(rootPostId);
            address newPostAuthor = feed.getPostAuthor(postId);
            require(
                graph.isFollowing({followerAccount: newPostAuthor, targetAccount: rootPostAuthor}), Errors.NotFollowing()
            );
        }
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* rootPostId */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _shouldRestrictionBeApplied(
        Configuration memory configuration,
        uint256 rootPostId,
        CreatePostParams calldata postParams
    ) internal view returns (bool) {
        IFeed feed = IFeed(msg.sender);
        if (feed.getPostAuthor(rootPostId) == postParams.author) {
            // Author can always reply, repost or quote their own posts.
            return false;
        }
        if (configuration.repliesRestricted && postParams.repliedPostId != 0) {
            uint256 repliedPostRootId = feed.getPost(postParams.repliedPostId).rootPostId;
            if (repliedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.repostsRestricted && postParams.repostedPostId != 0) {
            uint256 repostedPostRootId = feed.getPost(postParams.repostedPostId).rootPostId;
            if (repostedPostRootId == rootPostId) {
                return true;
            }
        }
        if (configuration.quotesRestricted && postParams.quotedPostId != 0) {
            uint256 quotedPostRootId = feed.getPost(postParams.quotedPostId).rootPostId;
            if (quotedPostRootId == rootPostId) {
                return true;
            }
        }
        return false;
    }
}
