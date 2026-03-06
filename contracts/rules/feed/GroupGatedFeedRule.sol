// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

/// @custom:keccak sense.param.group
bytes32 constant PARAM__GROUP = 0xdb0318b58d3d4af6266a695d509c507a8b3e5368108e3767b31e56520226e1aa;
/// @custom:keccak sense.param.repliesRestricted
bytes32 constant PARAM__REPLIES_RESTRICTED = 0x23eac1188784468413bdf97e250704295c67776c2a06aa5476f1bf4c61022456;
/// @custom:keccak sense.storage.GroupGatedFeedRule
bytes32 constant STORAGE__GROUP_GATED_FEED_RULE = 0xc546a3b31e75c3e2403f8f71e7338365bfb5293827ac0a3df19c8a4248b7639c;

contract GroupGatedFeedRule is IFeedRule, OwnableMetadataBasedRule, Initializable {
    struct Configuration {
        address groupGate;
        bool repliesRestricted;
    }

    struct Storage {
        mapping(address feed => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__GROUP_GATED_FEED_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration;
        // Restrict replies by default
        configuration.repliesRestricted = true;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__GROUP) {
                configuration.groupGate = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__REPLIES_RESTRICTED) {
                configuration.repliesRestricted = abi.decode(ruleParams[i].value, (bool));
            }
        }
        IGroup(configuration.groupGate).isMember(address(this)); // Aims to verify the provided address is a valid group
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256, /* postId */
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt];
        if (_shouldRestrictionBeApplied(configuration, postParams)) {
            require(IGroup(configuration.groupGate).isMember(postParams.author), Errors.NotAMember());
        }
    }

    function _shouldRestrictionBeApplied(Configuration memory configuration, CreatePostParams calldata postParams)
        internal
        pure
        returns (bool)
    {
        if (postParams.repliedPostId != 0) {
            return configuration.repliesRestricted;
        } else {
            return true;
        }
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }
}
