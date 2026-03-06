// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract AdditionRemovalPidGroupRule is OwnableMetadataBasedRule, Initializable, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak sense.param.accessControl
    bytes32 public constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;

    /// @custom:keccak sense.permission.AddMember
    uint256 constant PID__ADD_MEMBER = uint256(0x7975da81c3eb15a487a022674de548c87768be7c96c68d8f8560ea96b553a09c);
    /// @custom:keccak sense.permission.RemoveMember
    uint256 constant PID__REMOVE_MEMBER = uint256(0xdd20b5712d56709059ba6d5be4805add03a675fa6ffe2d8d6cb116b14fa6101f);

    /// @custom:keccak sense.storage.AdditionRemovalPidGroupRule
    bytes32 constant STORAGE__ADDITION_REMOVAL_PID_GROUP_RULE =
        0x3f6804c35b0bfe854fdeae6a157c686693c424e799a260b775cee23106030340;

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => address accessControl)) accessControl;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__ADDITION_REMOVAL_PID_GROUP_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__ADD_MEMBER, "sense.permission.AddMember");
        emit Events.Sense_PermissionId_Available(PID__REMOVE_MEMBER, "sense.permission.RemoveMember");
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
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
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, msg.sender, PID__ADD_MEMBER);
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        $storage().accessControl[msg.sender][configSalt].requireAccess(originalMsgSender, msg.sender, PID__REMOVE_MEMBER);
    }

    function processJoining(
        bytes32, /* configSalt */
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
