// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IRequestBasedGroupRule} from "contracts/core/interfaces/IRequestBasedGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract MembershipApprovalGroupRule is OwnableMetadataBasedRule, Initializable, IRequestBasedGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Sense_ApprovalGroupRule_MembershipRequested(
        address indexed group, bytes32 indexed configSalt, address indexed account
    );
    event Sense_ApprovalGroupRule_MembershipRequestCancelled(
        address indexed group, bytes32 indexed configSalt, address indexed account
    );
    event Sense_ApprovalGroupRule_MembershipApproved(
        address indexed group, bytes32 indexed configSalt, address indexed account, address approvedBy
    );
    event Sense_ApprovalGroupRule_MembershipRejected(
        address indexed group, bytes32 indexed configSalt, address indexed account, address rejectedBy
    );

    /// @custom:keccak sense.permission.ApproveMember
    uint256 constant PID__APPROVE_MEMBER = uint256(0x84cc5d3213761f9bf88f59e14e95fd410a9d936932353dbbd7990475bd6739e1);

    /// @custom:keccak sense.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;

    /// @custom:keccak sense.storage.MembershipApprovalGroupRule
    bytes32 constant STORAGE__MEMBERSHIP_APPROVAL_GROUP_RULE =
        0x30a288049a3a5a11dd194c58587101d28d76b83c3e1ea6946f2529a0789ff22e;

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => address accessControl)) accessControl;
        mapping(address group => mapping(address account => mapping(bytes32 configSalt => bool requested)))
            isMembershipRequested;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__MEMBERSHIP_APPROVAL_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__APPROVE_MEMBER, "sense.permission.ApproveMember");

        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function sendMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata /* params */ )
        external
        override
    {
        require($storage().isMembershipRequested[group][msg.sender][configSalt] == false, Errors.AlreadyExists());
        $storage().isMembershipRequested[group][msg.sender][configSalt] = true;
        emit Sense_ApprovalGroupRule_MembershipRequested(group, configSalt, msg.sender);
    }

    function cancelMembershipRequest(bytes32 configSalt, address group, KeyValue[] calldata /* params */ )
        external
        override
    {
        require($storage().isMembershipRequested[group][msg.sender][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[group][msg.sender][configSalt];
        emit Sense_ApprovalGroupRule_MembershipRequestCancelled(group, configSalt, msg.sender);
    }

    function rejectMembershipRequest(bytes32 configSalt, address group, address account) external {
        $storage().accessControl[group][configSalt].requireAccess(msg.sender, PID__APPROVE_MEMBER);
        _rejectMembershipRequest(configSalt, group, account);
    }

    function rejectMembershipRequests(bytes32 configSalt, address group, address[] calldata accounts) external {
        $storage().accessControl[group][configSalt].requireAccess(msg.sender, PID__APPROVE_MEMBER);
        for (uint256 i = 0; i < accounts.length; i++) {
            _rejectMembershipRequest(configSalt, group, accounts[i]);
        }
    }

    function _rejectMembershipRequest(bytes32 configSalt, address group, address account) internal {
        require($storage().isMembershipRequested[group][account][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[group][account][configSalt];
        emit Sense_ApprovalGroupRule_MembershipRejected(group, configSalt, account, msg.sender);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
                break;
            }
        }
        accessControl.verifyHasAccessFunction();
        $storage().accessControl[msg.sender][configSalt] = accessControl;
    }

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        require($storage().isMembershipRequested[msg.sender][account][configSalt], Errors.DoesNotExist());
        delete $storage().isMembershipRequested[msg.sender][account][configSalt];
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, PID__APPROVE_MEMBER);
        emit Sense_ApprovalGroupRule_MembershipApproved(msg.sender, configSalt, account, originalMsgSender);
    }

    function processJoining(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
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

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }
}
