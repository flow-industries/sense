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

contract UsernameLengthNamespaceRule is OwnableMetadataBasedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak sense.permission.SkipMinLengthRestriction
    uint256 constant PID__SKIP_MIN_LENGTH_RESTRICTION =
        uint256(0xee4356ed7332fd0dbf3b0921dc9b5ab4f0dca76f6a10af13634279c2af25c982);
    /// @custom:keccak sense.permission.SkipMaxLengthRestriction
    uint256 constant PID__SKIP_MAX_LENGTH_RESTRICTION =
        uint256(0x42a0c65a23ea799650863b1258137392414e3f36eb167b49fbc47f300091d94c);

    /// @custom:keccak sense.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;
    /// @custom:keccak sense.param.minLength
    bytes32 constant PARAM__MIN_LENGTH = 0x17f8670260ecfb903b0dacb96c4a353c84032897694a93984e140756003f5a11;
    /// @custom:keccak sense.param.maxLength
    bytes32 constant PARAM__MAX_LENGTH = 0x27439a3f2ad55861c0fdb81b5b901747d1ecaed457fc7730f095486fc7173105;

    /// @custom:keccak sense.storage.UsernameLengthNamespaceRule
    bytes32 constant STORAGE__USERNAME_LENGTH_NAMESPACE_RULE =
        0xddcd9f5b313e779b9cbd6aec5e4c407f9a28735d0b73f08f3fe41e6e513b9534;

    struct LengthRestrictions {
        uint8 min;
        uint8 max;
    }

    struct Configuration {
        address accessControl;
        LengthRestrictions lengthRestrictions;
    }

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_LENGTH_NAMESPACE_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(
            PID__SKIP_MIN_LENGTH_RESTRICTION, "sense.permission.SkipMinLengthRestriction"
        );
        emit Events.Sense_PermissionId_Available(
            PID__SKIP_MAX_LENGTH_RESTRICTION, "sense.permission.SkipMaxLengthRestriction"
        );
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        require(
            configuration.lengthRestrictions.max == 0
                || configuration.lengthRestrictions.min <= configuration.lengthRestrictions.max,
            Errors.InvalidParameter()
        ); // Min length cannot be greater than max length
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt];
        uint256 usernameLength = bytes(username).length;
        if (
            configuration.lengthRestrictions.min != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, PID__SKIP_MIN_LENGTH_RESTRICTION)
        ) {
            require(usernameLength >= configuration.lengthRestrictions.min, Errors.InvalidParameter());
        }
        if (
            configuration.lengthRestrictions.max != 0
                && !configuration.accessControl.hasAccess(originalMsgSender, PID__SKIP_MAX_LENGTH_RESTRICTION)
        ) {
            require(usernameLength <= configuration.lengthRestrictions.max, Errors.InvalidParameter());
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

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__MIN_LENGTH) {
                configuration.lengthRestrictions.min = abi.decode(params[i].value, (uint8));
            } else if (params[i].key == PARAM__MAX_LENGTH) {
                configuration.lengthRestrictions.max = abi.decode(params[i].value, (uint8));
            }
        }
        return configuration;
    }
}
