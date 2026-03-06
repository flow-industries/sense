// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue, RuleProcessingParams} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract BanMemberGroupRule is OwnableMetadataBasedRule, Initializable, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Sense_BanMemberGroupRule_MemberBanned(address indexed group, address indexed bannedAccount, address bannedBy);
    event Sense_BanMemberGroupRule_MemberUnbanned(
        address indexed group, address indexed unbannedAccount, address unbannedBy
    );

    /// @custom:keccak sense.permission.BanMember
    uint256 public constant PID__BAN_MEMBER = uint256(0xaf31e8d9940e5b03249813e4baab1f01daa7078bc9f5c4f3d531037c68a0b6eb);
    /// @custom:keccak sense.permission.UnbanMember
    uint256 public constant PID__UNBAN_MEMBER =
        uint256(0x129dec3080b4ca4095f9e190fc4d29e2495dbcf7fda2914a3f69f9ad38c03b73);

    /// @custom:keccak sense.param.accessControl
    bytes32 public constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;
    /// @custom:keccak sense.param.banMember
    bytes32 public constant PARAM__BAN_MEMBER = 0xac71932fb703ea33d908cf1ccd9dd167238d47b02e7673055d55a65d09ea8a24;

    /// @custom:keccak sense.storage.BanMemberGroupRule
    bytes32 constant STORAGE__BAN_MEMBER_GROUP_RULE = 0x24b18f6aac227a2338ac5585b6c852dc187a0734b1c689e78e3b4e1dc2a750de;

    struct Storage {
        mapping(address group => address accessControl) groupAccessControl;
        mapping(address group => mapping(address account => bool isBanned)) isMemberBanned;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__BAN_MEMBER_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__BAN_MEMBER, "sense.permission.BanMember");
        emit Events.Sense_PermissionId_Available(PID__UNBAN_MEMBER, "sense.permission.UnbanMember");
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function ban(
        address group,
        address account,
        KeyValue[] calldata groupParams,
        RuleProcessingParams[] calldata groupRuleProcessingParams
    ) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__BAN_MEMBER);
        _ban(group, account, msg.sender);
        if (IGroup(group).isMember(account)) {
            IGroup(group).removeMember(account, groupParams, groupRuleProcessingParams);
        }
    }

    function unban(address group, address account) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__UNBAN_MEMBER);
        _unban(group, account, msg.sender);
    }

    struct MemberBatchParams {
        address account;
        KeyValue[] customParams;
        RuleProcessingParams[] ruleProcessingParams;
    }

    function ban(address group, MemberBatchParams[] calldata membersToBan) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__BAN_MEMBER);
        for (uint256 i = 0; i < membersToBan.length; i++) {
            _ban(group, membersToBan[i].account, msg.sender);
            if (IGroup(group).isMember(membersToBan[i].account)) {
                IGroup(group).removeMember(
                    membersToBan[i].account, membersToBan[i].customParams, membersToBan[i].ruleProcessingParams
                );
            }
        }
    }

    function unban(address group, address[] calldata accounts) external {
        $storage().groupAccessControl[group].requireAccess(msg.sender, group, PID__UNBAN_MEMBER);
        for (uint256 i = 0; i < accounts.length; i++) {
            _unban(group, accounts[i], msg.sender);
        }
    }

    function isMemberBanned(address group, address account) external view returns (bool) {
        return $storage().isMemberBanned[group][account];
    }

    /**
     * If multiple instances of this rule are configured for the same group (which is a bad practice),
     * only the last configuration will be applied (as it will override the previous ones).
     */
    function configure(bytes32, /* configSalt */ KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
                break;
            }
        }
        accessControl.verifyHasAccessFunction();
        $storage().groupAccessControl[msg.sender] = accessControl;
    }

    function processAddition(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _requireNotBanned({group: msg.sender, account: account});
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processJoining(
        bytes32, /* configSalt */
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _requireNotBanned({group: msg.sender, account: account});
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _unban(address group, address account, address unbannedBy) internal {
        $storage().isMemberBanned[group][account] = false;
        emit Sense_BanMemberGroupRule_MemberUnbanned(group, account, unbannedBy);
    }

    function _ban(address group, address account, address bannedBy) internal {
        $storage().isMemberBanned[group][account] = true;
        emit Sense_BanMemberGroupRule_MemberBanned(group, account, bannedBy);
    }

    function _requireNotBanned(address group, address account) internal view {
        require($storage().isMemberBanned[group][account] == false, Errors.Banned());
    }
}
