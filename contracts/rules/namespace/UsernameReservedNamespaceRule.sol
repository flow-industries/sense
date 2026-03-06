// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract UsernameReservedNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    event Sense_UsernameReservedNamespaceRule_UsernameReserved(
        address indexed usernamePrimitive, bytes32 indexed configSalt, string indexed indexedUsername, string username
    );
    event Sense_UsernameReservedNamespaceRule_UsernameReleased(
        address indexed usernamePrimitive, bytes32 indexed configSalt, string indexed indexedUsername, string username
    );
    event Sense_UsernameReservedNamespaceRule_ReservedUsernameCreated(
        address indexed usernamePrimitive,
        bytes32 indexed configSalt,
        string indexed indexedUsername,
        string username,
        address account,
        address createdBy
    );

    /// @custom:keccak sense.permission.CreateReservedUsername
    uint256 constant PID__CREATE_RESERVED_USERNAME =
        uint256(0x1309d301ab7e698e15b7f5f1e60b960d99fc20245a2805114ccf6f5c6b80aaf1);

    /// @custom:keccak sense.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;
    /// @custom:keccak sense.param.usernamesToReserve
    bytes32 constant PARAM__USERNAMES_TO_RESERVE = 0xe1f317d50dd4083bc89665d97030636bf18f985b6842103710e4adc054345b85;
    /// @custom:keccak sense.param.usernamesToRelease
    bytes32 constant PARAM__USERNAMES_TO_RELEASE = 0x2ea0d35e0ddab93a6ca79311b27f3431d66ae58a09cc8e94fd7b59108f68fd57;

    /// @custom:keccak sense.storage.UsernameReservedNamespaceRule
    bytes32 constant STORAGE__USERNAME_RESERVED_NAMESPACE_RULE =
        0x7bbb7a30cc4bb651fea38ee25587a6a2a490f36190f7a54dfbf61eca3f36287c;

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => address accessControl)) accessControl;
        mapping(address namespace => mapping(bytes32 configSalt => mapping(string username => bool reserved)))
            isUsernameReserved;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_RESERVED_NAMESPACE_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(
            PID__CREATE_RESERVED_USERNAME, "sense.permission.CreateReservedUsername"
        );
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address accessControl;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__ACCESS_CONTROL) {
                accessControl = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__USERNAMES_TO_RESERVE) {
                string[] memory usernamesToReserve = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToReserve.length; j++) {
                    require(
                        !$storage().isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]],
                        Errors.RedundantStateChange()
                    );
                    $storage().isUsernameReserved[msg.sender][configSalt][usernamesToReserve[j]] = true;
                    emit Sense_UsernameReservedNamespaceRule_UsernameReserved(
                        msg.sender, configSalt, usernamesToReserve[j], usernamesToReserve[j]
                    );
                }
            } else if (ruleParams[i].key == PARAM__USERNAMES_TO_RELEASE) {
                string[] memory usernamesToRelease = abi.decode(ruleParams[i].value, (string[]));
                for (uint256 j = 0; j < usernamesToRelease.length; j++) {
                    require(
                        $storage().isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]],
                        Errors.RedundantStateChange()
                    );
                    $storage().isUsernameReserved[msg.sender][configSalt][usernamesToRelease[j]] = false;
                    emit Sense_UsernameReservedNamespaceRule_UsernameReleased(
                        msg.sender, configSalt, usernamesToRelease[j], usernamesToRelease[j]
                    );
                }
            }
        }
        accessControl.verifyHasAccessFunction();
        $storage().accessControl[msg.sender][configSalt] = accessControl;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address account,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external override {
        if ($storage().isUsernameReserved[msg.sender][configSalt][username]) {
            $storage().accessControl[msg.sender][configSalt].requireAccess(
                originalMsgSender, PID__CREATE_RESERVED_USERNAME
            );
            emit Sense_UsernameReservedNamespaceRule_ReservedUsernameCreated(
                msg.sender, configSalt, username, username, account, originalMsgSender
            );
        }
    }

    function processRemoval(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processAssigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processUnassigning(
        bytes32, /* configSalt */
        address, /* originalMsgSender */
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }
}
