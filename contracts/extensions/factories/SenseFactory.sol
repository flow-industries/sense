// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IRoleBasedAccessControl} from "contracts/core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Group} from "contracts/core/primitives/group/Group.sol";
import {PermissionlessAccessControl} from "contracts/extensions/access/PermissionlessAccessControl.sol";
import {
    RuleChange,
    RuleProcessingParams,
    RuleSelectorChange,
    RuleConfigurationChange,
    KeyValue,
    SourceStamp
} from "contracts/core/types/Types.sol";
import {GroupFactory} from "contracts/extensions/factories/GroupFactory.sol";
import {FeedFactory} from "contracts/extensions/factories/FeedFactory.sol";
import {GraphFactory} from "contracts/extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "contracts/extensions/factories/NamespaceFactory.sol";
import {AppFactory} from "contracts/extensions/factories/AppFactory.sol";
import {AppInitialProperties} from "contracts/extensions/primitives/app/App.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {AccountFactory} from "contracts/extensions/factories/AccountFactory.sol";
import {IAccount, AccountManagerPermissions} from "contracts/extensions/account/IAccount.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {SenseUsernameTokenURIProvider} from "contracts/core/primitives/namespace/SenseUsernameTokenURIProvider.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";

import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGraphRule} from "contracts/core/interfaces/IGraphRule.sol";
import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";

import {PARAM__GROUP, PARAM__REPLIES_RESTRICTED} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {Errors} from "contracts/core/types/Errors.sol";

import {BanMemberGroupRule} from "contracts/rules/group/BanMemberGroupRule.sol";

import {LibString} from "solady/src/utils/LibString.sol";

/// @custom:keccak sense.data.groupFeed
bytes32 constant DATA__GROUP_LINKED_FEED = 0x97e2332645a38ca075abdbdadb2ed1fb3410f7f276b1d2687966f500db9285bb;

/// @custom:keccak sense.param.accessControl
bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;

struct CreateAccountParams {
    string metadataURI;
    address owner;
    address[] accountManagers;
    AccountManagerPermissions[] accountManagersPermissions;
    SourceStamp accountCreationSourceStamp;
    KeyValue[] accountExtraData;
}

struct CreateUsernameParams {
    string username;
    KeyValue[] createUsernameCustomParams;
    RuleProcessingParams[] createUsernameRuleProcessingParams;
    KeyValue[] assignUsernameCustomParams;
    RuleProcessingParams[] assignRuleProcessingParams;
    KeyValue[] usernameExtraData;
}

struct FactoryConstructorParams {
    AccessControlFactory accessControlFactory;
    AccountFactory accountFactory;
    AppFactory appFactory;
    GroupFactory groupFactory;
    FeedFactory feedFactory;
    GraphFactory graphFactory;
    NamespaceFactory namespaceFactory;
}

struct RuleConstructorParams {
    address accountBlockingRule;
    address groupGatedFeedRule;
    address usernameSimpleCharsetRule;
    address banMemberGroupRule;
    address addRemovePidGroupRule;
    address usernameReservedNamespaceRule;
}

struct GroupWithFeed_GroupParams {
    string groupMetadataURI;
    RuleChange[] groupRules;
    KeyValue[] groupExtraData;
    address groupFoundingMember;
}

struct GroupWithFeed_FeedParams {
    string feedMetadataURI;
    RuleChange[] feedRules;
    KeyValue[] feedExtraData;
    bool allowNonMembersToReply;
}

contract SenseFactory {
    using LibString for string;

    AccessControlFactory internal immutable ACCESS_CONTROL_FACTORY;
    AccountFactory internal immutable ACCOUNT_FACTORY;
    AppFactory internal immutable APP_FACTORY;
    GroupFactory internal immutable GROUP_FACTORY;
    FeedFactory internal immutable FEED_FACTORY;
    GraphFactory internal immutable GRAPH_FACTORY;
    NamespaceFactory internal immutable NAMESPACE_FACTORY;
    IAccessControl internal immutable TEMPORARY_ACCESS_CONTROL;
    address internal immutable ACCOUNT_BLOCKING_RULE;
    address internal immutable GROUP_GATED_FEED_RULE;
    address internal immutable USERNAME_SIMPLE_CHARSET_RULE;
    address internal immutable BAN_MEMBER_GROUP_RULE;
    address internal immutable ADD_REMOVE_PID_GROUP_RULE;
    address internal immutable USERNAME_RESERVED_NAMESPACE_RULE;

    uint128 internal immutable namespaceAllowedCharsLookup;

    constructor(FactoryConstructorParams memory factories, RuleConstructorParams memory rules) {
        ACCESS_CONTROL_FACTORY = factories.accessControlFactory;
        ACCOUNT_FACTORY = factories.accountFactory;
        APP_FACTORY = factories.appFactory;
        GROUP_FACTORY = factories.groupFactory;
        FEED_FACTORY = factories.feedFactory;
        GRAPH_FACTORY = factories.graphFactory;
        NAMESPACE_FACTORY = factories.namespaceFactory;
        TEMPORARY_ACCESS_CONTROL = new PermissionlessAccessControl();
        ACCOUNT_BLOCKING_RULE = rules.accountBlockingRule;
        GROUP_GATED_FEED_RULE = rules.groupGatedFeedRule;
        USERNAME_SIMPLE_CHARSET_RULE = rules.usernameSimpleCharsetRule;
        BAN_MEMBER_GROUP_RULE = rules.banMemberGroupRule;
        ADD_REMOVE_PID_GROUP_RULE = rules.addRemovePidGroupRule;
        USERNAME_RESERVED_NAMESPACE_RULE = rules.usernameReservedNamespaceRule;
        namespaceAllowedCharsLookup = string("abcdefghijklmnopqrstuvwxyz0123456789_").to7BitASCIIAllowedLookup();
    }

    function createAccountWithUsernameFree(
        address namespacePrimitiveAddress,
        CreateAccountParams calldata accountParams,
        CreateUsernameParams calldata usernameParams
    ) external returns (address) {
        address account = ACCOUNT_FACTORY.deployAccount(
            address(this),
            accountParams.metadataURI,
            accountParams.accountManagers,
            accountParams.accountManagersPermissions,
            accountParams.accountCreationSourceStamp,
            accountParams.accountExtraData
        );
        INamespace namespacePrimitive = INamespace(namespacePrimitiveAddress);
        bytes memory txData = abi.encodeCall(
            namespacePrimitive.createUsername,
            (
                account,
                usernameParams.username,
                usernameParams.createUsernameCustomParams,
                usernameParams.createUsernameRuleProcessingParams,
                usernameParams.usernameExtraData
            )
        );
        IAccount(payable(account)).executeTransaction(namespacePrimitiveAddress, uint256(0), txData);
        txData = abi.encodeCall(
            namespacePrimitive.assignUsername,
            (
                account,
                usernameParams.username,
                usernameParams.assignUsernameCustomParams,
                new RuleProcessingParams[](0),
                new RuleProcessingParams[](0),
                usernameParams.assignRuleProcessingParams
            )
        );
        IAccount(payable(account)).executeTransaction(namespacePrimitiveAddress, uint256(0), txData);
        IOwnable(account).transferOwnership(accountParams.owner);
        IOwnable(BeaconProxy(payable(account)).proxy__getProxyAdmin()).transferOwnership(accountParams.owner);
        return account;
    }

    struct CreateGroupWithFeedParams {
        address owner;
        address group;
        IRoleBasedAccessControl groupAccessControl;
        IRoleBasedAccessControl feedAccessControl;
        RuleChange[] modifiedFeedRules;
        string feedMetadataURI;
        RuleChange[] feedRules;
        KeyValue[] feedExtraData;
    }

    function createGroupWithFeed(
        address owner,
        address[] memory admins,
        GroupWithFeed_GroupParams memory groupParams,
        GroupWithFeed_FeedParams memory feedParams
    ) external returns (address, address) {
        CreateGroupWithFeedParams memory s;
        s.feedExtraData = feedParams.feedExtraData;
        s.feedRules = feedParams.feedRules;
        s.feedMetadataURI = feedParams.feedMetadataURI;
        s.feedAccessControl = _deployAccessControl(owner, admins);
        {
            s.groupAccessControl = _deployAccessControl(owner, _addBanRuleToGroupAdmins(admins));
        }
        s.owner = owner;

        {
            if (groupParams.groupFoundingMember != address(0)) {
                require(groupParams.groupFoundingMember == msg.sender, Errors.InvalidParameter());
            }
            s.group = GROUP_FACTORY.deployGroup(
                groupParams.groupMetadataURI,
                TEMPORARY_ACCESS_CONTROL,
                s.owner,
                _prepareGroupRules(groupParams.groupRules, address(s.groupAccessControl)),
                groupParams.groupExtraData,
                groupParams.groupFoundingMember
            );
        }

        s.modifiedFeedRules =
            _prepareFeedRulesBasedOnGroup(s.feedRules, s.feedAccessControl, s.group, feedParams.allowNonMembersToReply);

        address feed = FEED_FACTORY.deployFeed(
            s.feedMetadataURI, s.feedAccessControl, s.owner, s.modifiedFeedRules, s.feedExtraData
        );

        KeyValue[] memory groupExtraDataWithFeed = new KeyValue[](1);
        groupExtraDataWithFeed[0] = KeyValue({key: DATA__GROUP_LINKED_FEED, value: abi.encode(feed)});
        IGroup(s.group).setExtraData(groupExtraDataWithFeed);
        AccessControlled(s.group).setAccessControl(s.groupAccessControl);
        return (s.group, feed);
    }

    function deployAccount(
        string calldata metadataURI,
        address owner,
        address[] calldata accountManagers,
        AccountManagerPermissions[] calldata accountManagersPermissions,
        SourceStamp calldata sourceStamp,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return ACCOUNT_FACTORY.deployAccount(
            owner, metadataURI, accountManagers, accountManagersPermissions, sourceStamp, extraData
        );
    }

    function deployApp(
        string calldata metadataURI,
        bool sourceStampVerificationEnabled,
        address owner,
        address[] calldata admins,
        AppInitialProperties calldata initialProperties,
        KeyValue[] calldata extraData
    ) external returns (address) {
        return APP_FACTORY.deployApp(
            metadataURI,
            sourceStampVerificationEnabled,
            _deployAccessControl(owner, admins),
            owner,
            initialProperties,
            extraData
        );
    }

    function deployGroup(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData,
        address foundingMember
    ) external returns (address) {
        if (foundingMember != address(0)) {
            require(foundingMember == msg.sender, Errors.InvalidParameter());
        }
        IRoleBasedAccessControl accessControl = _deployAccessControl(owner, _addBanRuleToGroupAdmins(admins));
        return GROUP_FACTORY.deployGroup(
            metadataURI,
            accessControl,
            owner,
            _prepareGroupRules(rules, address(accessControl)),
            extraData,
            foundingMember
        );
    }

    function deployFeed(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData
    ) external returns (address) {
        IRoleBasedAccessControl accessControl = _deployAccessControl(owner, admins);
        return FEED_FACTORY.deployFeed(
            metadataURI,
            accessControl,
            owner,
            _prepareRules(rules, IFeedRule.processCreatePost.selector, address(accessControl)),
            extraData
        );
    }

    function deployGraph(
        string calldata metadataURI,
        address owner,
        address[] calldata admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData
    ) external returns (address) {
        IRoleBasedAccessControl accessControl = _deployAccessControl(owner, admins);
        return GRAPH_FACTORY.deployGraph(
            metadataURI,
            accessControl,
            owner,
            _prepareRules(rules, IGraphRule.processFollow.selector, address(accessControl)),
            extraData
        );
    }

    function deployNamespace(
        string memory namespace,
        string memory metadataURI,
        address owner,
        address[] memory admins,
        RuleChange[] calldata rules,
        KeyValue[] calldata extraData,
        string memory nftName,
        string memory nftSymbol
    ) external returns (address) {
        _validateNamespaceStrings(namespace, nftName, nftSymbol);
        IRoleBasedAccessControl accessControl = _deployAccessControl(owner, admins);
        RuleChange[] memory modifiedRules = _injectRulesForNamespace(rules, address(accessControl));

        return NAMESPACE_FACTORY.deployNamespace(
            namespace,
            metadataURI,
            accessControl,
            owner,
            modifiedRules,
            extraData,
            nftName,
            nftSymbol,
            new SenseUsernameTokenURIProvider()
        );
    }

    function _validateNamespaceStrings(string memory namespace, string memory nftName, string memory nftSymbol)
        internal
        view
    {
        require(bytes(namespace).length > 0 && bytes(namespace).length < type(uint8).max, Errors.InvalidParameter());
        require(bytes(nftName).length > 0 && bytes(nftName).length < type(uint8).max, Errors.InvalidParameter());
        require(bytes(nftSymbol).length > 0 && bytes(nftSymbol).length < type(uint8).max, Errors.InvalidParameter());

        require(nftName.is7BitASCII(), Errors.InvalidParameter());
        require(nftSymbol.is7BitASCII(), Errors.InvalidParameter());

        require(namespace.is7BitASCII(namespaceAllowedCharsLookup), Errors.InvalidParameter());
        require(namespace.eq("sense") == false, Errors.InvalidParameter());
        require(bytes(namespace)[0] != "_", Errors.InvalidParameter());
    }

    function _deployAccessControl(address owner, address[] memory admins)
        internal
        virtual
        returns (IRoleBasedAccessControl)
    {
        return ACCESS_CONTROL_FACTORY.deployOwnerAdminOnlyAccessControl(owner, admins);
    }

    function _injectRuleAccessControl(RuleChange memory rule, address accessControl)
        internal
        pure
        virtual
        returns (RuleChange memory)
    {
        bool found;
        if (rule.configurationChanges.configure) {
            for (uint256 i = 0; i < rule.configurationChanges.ruleParams.length; i++) {
                if (rule.configurationChanges.ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                    require(!found, Errors.DuplicatedValue());
                    found = true;
                    require(rule.configurationChanges.ruleParams[i].value.length == 0, Errors.InvalidParameter());
                    rule.configurationChanges.ruleParams[i].value = abi.encode(accessControl);
                }
            }
        }
        return rule;
    }

    function _injectRuleAccessControl(RuleChange[] memory rules, address accessControl)
        internal
        pure
        virtual
        returns (RuleChange[] memory)
    {
        RuleChange[] memory modifiedRules = new RuleChange[](rules.length);
        for (uint256 i = 0; i < rules.length; i++) {
            modifiedRules[i] = _injectRuleAccessControl(rules[i], accessControl);
        }
        return modifiedRules;
    }

    function _addBanRuleToGroupAdmins(address[] memory admins) internal view returns (address[] memory) {
        address[] memory modifiedAdmins = new address[](admins.length + 1);
        for (uint256 i = 0; i < admins.length; i++) {
            modifiedAdmins[i] = admins[i];
        }
        modifiedAdmins[admins.length] = BAN_MEMBER_GROUP_RULE;
        return modifiedAdmins;
    }

    function _prepareGroupRules(RuleChange[] memory rules, address accessControl)
        internal
        view
        virtual
        returns (RuleChange[] memory)
    {
        // Current passed rules + AdditionRemovalPidGroupRule + BanMemberGroupRule
        RuleChange[] memory modifiedRules = new RuleChange[](rules.length + 2);
        modifiedRules[0] = _getAddRemovePidGroupRuleAsRuleChange(accessControl);
        modifiedRules[1] = _getBanGroupRuleAsRuleChange(accessControl);
        for (uint256 i = 0; i < rules.length; i++) {
            require(rules[i].ruleAddress != BAN_MEMBER_GROUP_RULE, Errors.DuplicatedValue());
            require(rules[i].ruleAddress != ADD_REMOVE_PID_GROUP_RULE, Errors.DuplicatedValue());
            modifiedRules[i + 1] = _injectRuleAccessControl(rules[i], accessControl);
        }
        return modifiedRules;
    }

    function _getAddRemovePidGroupRuleAsRuleChange(address accessControl) internal view returns (RuleChange memory) {
        RuleSelectorChange[] memory addRemovePidRuleSelectorChanges = new RuleSelectorChange[](2);
        KeyValue[] memory addRemovePidRuleConfigParams = new KeyValue[](1);
        // Set the Access Control configuration parameter
        addRemovePidRuleConfigParams[0] = KeyValue({key: PARAM__ACCESS_CONTROL, value: abi.encode(accessControl)});
        // Enable it as required rule for processAddition selector
        addRemovePidRuleSelectorChanges[0] =
            RuleSelectorChange({ruleSelector: IGroupRule.processAddition.selector, isRequired: true, enabled: true});
        // Enable it as required rule for processRemoval selector
        addRemovePidRuleSelectorChanges[1] =
            RuleSelectorChange({ruleSelector: IGroupRule.processRemoval.selector, isRequired: true, enabled: true});
        return RuleChange({
            ruleAddress: ADD_REMOVE_PID_GROUP_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: addRemovePidRuleConfigParams}),
            selectorChanges: addRemovePidRuleSelectorChanges
        });
    }

    function _getBanGroupRuleAsRuleChange(address accessControl) internal view returns (RuleChange memory) {
        RuleSelectorChange[] memory banRuleSelectorChanges = new RuleSelectorChange[](1);
        KeyValue[] memory banRuleConfigParams = new KeyValue[](1);
        banRuleConfigParams[0] = KeyValue({key: PARAM__ACCESS_CONTROL, value: abi.encode(accessControl)});
        banRuleSelectorChanges[0] =
            RuleSelectorChange({ruleSelector: IGroupRule.processJoining.selector, isRequired: true, enabled: true});
        return RuleChange({
            ruleAddress: BAN_MEMBER_GROUP_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: banRuleConfigParams}),
            selectorChanges: banRuleSelectorChanges
        });
    }

    function _prepareRules(RuleChange[] memory rules, bytes4 ruleSelector, address accessControl)
        internal
        view
        virtual
        returns (RuleChange[] memory)
    {
        RuleChange[] memory modifiedRules = new RuleChange[](rules.length + 1);
        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        selectorChanges[0] = RuleSelectorChange({ruleSelector: ruleSelector, isRequired: true, enabled: true});
        modifiedRules[0] = RuleChange({
            ruleAddress: ACCOUNT_BLOCKING_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });
        for (uint256 i = 0; i < rules.length; i++) {
            require(rules[i].ruleAddress != ACCOUNT_BLOCKING_RULE, Errors.DuplicatedValue());
            modifiedRules[i + 1] = _injectRuleAccessControl(rules[i], accessControl);
        }
        return modifiedRules;
    }

    function _prepareFeedRulesBasedOnGroup(
        RuleChange[] memory feedRules,
        IRoleBasedAccessControl feedAccessControl,
        address group,
        bool allowNonMembersToReply
    ) internal view virtual returns (RuleChange[] memory) {
        RuleChange[] memory modifiedFeedRules = new RuleChange[](feedRules.length + 2);

        RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
        // Both rules only operate on IFeedRule.processCreatePost.selector (at least at the moment of writing this)
        selectorChanges[0] =
            RuleSelectorChange({ruleSelector: IFeedRule.processCreatePost.selector, isRequired: true, enabled: true});

        modifiedFeedRules[0] = RuleChange({
            ruleAddress: ACCOUNT_BLOCKING_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
            selectorChanges: selectorChanges
        });

        KeyValue[] memory groupGatedRuleParams = new KeyValue[](2);
        groupGatedRuleParams[0] = KeyValue({key: PARAM__GROUP, value: abi.encode(group)});
        groupGatedRuleParams[1] = KeyValue({key: PARAM__REPLIES_RESTRICTED, value: abi.encode(!allowNonMembersToReply)});

        modifiedFeedRules[1] = RuleChange({
            ruleAddress: GROUP_GATED_FEED_RULE,
            configSalt: bytes32(0),
            configurationChanges: RuleConfigurationChange({configure: true, ruleParams: groupGatedRuleParams}),
            selectorChanges: selectorChanges
        });

        for (uint256 i = 0; i < feedRules.length; i++) {
            require(feedRules[i].ruleAddress != ACCOUNT_BLOCKING_RULE, Errors.DuplicatedValue());
            require(feedRules[i].ruleAddress != GROUP_GATED_FEED_RULE, Errors.DuplicatedValue());
            modifiedFeedRules[i + 2] = _injectRuleAccessControl(feedRules[i], address(feedAccessControl));
        }

        return modifiedFeedRules;
    }

    function _injectRulesForNamespace(RuleChange[] memory rules, address accessControl)
        internal
        view
        virtual
        returns (RuleChange[] memory)
    {
        RuleChange[] memory modifiedRules = new RuleChange[](rules.length + 2);

        {
            RuleSelectorChange[] memory selectorChanges = new RuleSelectorChange[](1);
            selectorChanges[0] = RuleSelectorChange({
                ruleSelector: INamespaceRule.processCreation.selector,
                isRequired: true,
                enabled: true
            });
            modifiedRules[0] = RuleChange({
                ruleAddress: USERNAME_SIMPLE_CHARSET_RULE,
                configSalt: bytes32(0),
                configurationChanges: RuleConfigurationChange({configure: true, ruleParams: new KeyValue[](0)}),
                selectorChanges: selectorChanges
            });

            KeyValue[] memory usernameReservedNamespaceRuleConfigParams = new KeyValue[](1);
            // Set the Access Control configuration parameter
            usernameReservedNamespaceRuleConfigParams[0] =
                KeyValue({key: PARAM__ACCESS_CONTROL, value: abi.encode(accessControl)});

            modifiedRules[1] = RuleChange({
                ruleAddress: USERNAME_RESERVED_NAMESPACE_RULE,
                configSalt: bytes32(0),
                configurationChanges: RuleConfigurationChange({
                    configure: true,
                    ruleParams: usernameReservedNamespaceRuleConfigParams
                }),
                selectorChanges: selectorChanges
            });
            for (uint256 i = 0; i < rules.length; i++) {
                require(rules[i].ruleAddress != USERNAME_SIMPLE_CHARSET_RULE, Errors.DuplicatedValue());
                require(rules[i].ruleAddress != USERNAME_RESERVED_NAMESPACE_RULE, Errors.DuplicatedValue());
                modifiedRules[i + 2] = _injectRuleAccessControl(rules[i], address(accessControl));
            }
        }

        return modifiedRules;
    }

    /// @custom:keccak sense.address.AccessControlFactory
    bytes32 constant ADDRESS__ACCESS_CONTROL_FACTORY = 0xe6cc7eccbc50c19bb77e842442884d48b5072b219777ec2b82cfe92029017969;
    /// @custom:keccak sense.address.AccountFactory
    bytes32 constant ADDRESS__ACCOUNT_FACTORY = 0x0bc9497f13cafc577febbc8dfd4d309c8c7c4537967ce632fea24c4c283d888b;
    /// @custom:keccak sense.address.AppFactory
    bytes32 constant ADDRESS__APP_FACTORY = 0x8b0bd5520cf6adeebdde210ac0eea6dc3eb24400ba59de57408276d3cdd0c2c6;
    /// @custom:keccak sense.address.FeedFactory
    bytes32 constant ADDRESS__FEED_FACTORY = 0xa64475f3dba151012ea4053461625e31eb356f0397c4318485ed3d7441584364;
    /// @custom:keccak sense.address.GraphFactory
    bytes32 constant ADDRESS__GRAPH_FACTORY = 0xc5caf6bc44d71f6b6e562a37c5c03923c9e5fd715417b4e815973c528130d59d;
    /// @custom:keccak sense.address.GroupFactory
    bytes32 constant ADDRESS__GROUP_FACTORY = 0xcaad39b1e89d7d2de413a34f1ee86143edde2d73374760d444cb7e7b842abb4a;
    /// @custom:keccak sense.address.NamespaceFactory
    bytes32 constant ADDRESS__NAMESPACE_FACTORY = 0x1e973de3cf8d54aab77d1bc95d5ca53c163537f3246785317169d6b4d4c44b0c;

    function getFactories() external view returns (KeyValue[] memory) {
        KeyValue[] memory factories = new KeyValue[](7);
        factories[0] = KeyValue({key: ADDRESS__ACCESS_CONTROL_FACTORY, value: abi.encode(ACCESS_CONTROL_FACTORY)});
        factories[1] = KeyValue({key: ADDRESS__ACCOUNT_FACTORY, value: abi.encode(ACCOUNT_FACTORY)});
        factories[2] = KeyValue({key: ADDRESS__APP_FACTORY, value: abi.encode(APP_FACTORY)});
        factories[3] = KeyValue({key: ADDRESS__FEED_FACTORY, value: abi.encode(FEED_FACTORY)});
        factories[4] = KeyValue({key: ADDRESS__GRAPH_FACTORY, value: abi.encode(GRAPH_FACTORY)});
        factories[5] = KeyValue({key: ADDRESS__GROUP_FACTORY, value: abi.encode(GROUP_FACTORY)});
        factories[6] = KeyValue({key: ADDRESS__NAMESPACE_FACTORY, value: abi.encode(NAMESPACE_FACTORY)});
        return factories;
    }

    function getTemporaryAccessControl() external view returns (address) {
        return address(TEMPORARY_ACCESS_CONTROL);
    }

    /// @custom:keccak sense.address.AccountBlockingRule
    bytes32 constant ADDRESS__ACCOUNT_BLOCKING_RULE = 0xb38a5e8a3d7d5911a7e43e72de972a22da4cc00cf1548240bf3ce79cf2d39266;
    /// @custom:keccak sense.address.GroupGatedFeedRule
    bytes32 constant ADDRESS__GROUP_GATED_FEED_RULE = 0xe3ad50437bef3fc97378a7eb22a53f9f11e4221bdd41bba74862c8d602d8d92a;
    /// @custom:keccak sense.address.UsernameSimpleCharsetNamespaceRule
    bytes32 constant ADDRESS__USERNAME_SIMPLE_CHARSET_RULE =
        0x11fee1f2ace42d2098ce4fcb056a41262ca58d084a6f3e00b68cc28809785251;
    /// @custom:keccak sense.address.BanMemberGroupRule
    bytes32 constant ADDRESS__BAN_MEMBER_GROUP_RULE = 0x5cffae06ef50af173a2650739fa4622ce58b1dd4149f1ae3cd6bc124040ce2fc;
    /// @custom:keccak sense.address.AdditionRemovalPidGroupRule
    bytes32 constant ADDRESS__ADD_REMOVE_PID_GROUP_RULE =
        0x4d4b2b9d1081804fec085143adf351b8881e94a201bc9d967ec50944a9043c98;
    /// @custom:keccak sense.address.UsernameReservedNamespaceRule
    bytes32 constant ADDRESS__USERNAME_RESERVED_NAMESPACE_RULE =
        0xe9b066d3189c31dec06e5d5de6c2f826602863504da2687eb8e0480f145edd57;

    function getRules() external view returns (KeyValue[] memory) {
        KeyValue[] memory rules = new KeyValue[](6);
        rules[0] = KeyValue({key: ADDRESS__ACCOUNT_BLOCKING_RULE, value: abi.encode(ACCOUNT_BLOCKING_RULE)});
        rules[1] = KeyValue({key: ADDRESS__GROUP_GATED_FEED_RULE, value: abi.encode(GROUP_GATED_FEED_RULE)});
        rules[2] =
            KeyValue({key: ADDRESS__USERNAME_SIMPLE_CHARSET_RULE, value: abi.encode(USERNAME_SIMPLE_CHARSET_RULE)});
        rules[3] = KeyValue({key: ADDRESS__BAN_MEMBER_GROUP_RULE, value: abi.encode(BAN_MEMBER_GROUP_RULE)});
        rules[4] = KeyValue({key: ADDRESS__ADD_REMOVE_PID_GROUP_RULE, value: abi.encode(ADD_REMOVE_PID_GROUP_RULE)});
        rules[5] = KeyValue({
            key: ADDRESS__USERNAME_RESERVED_NAMESPACE_RULE,
            value: abi.encode(USERNAME_RESERVED_NAMESPACE_RULE)
        });
        return rules;
    }
}
