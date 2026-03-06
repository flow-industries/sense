// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {TokenGatedRule} from "contracts/rules/base/TokenGatedRule.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

contract TokenGatedNamespaceRule is TokenGatedRule, Initializable, INamespaceRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak sense.permission.SkipGate
    uint256 constant PID__SKIP_GATE = uint256(0x9c121722c489db51d51806a75ad147e0ea1b081f6236c9d68afaa6100116d370);

    /// @custom:keccak sense.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;

    /// @custom:keccak sense.storage.TokenGatedNamespaceRule
    bytes32 constant STORAGE__TOKEN_GATED_NAMESPACE_RULE =
        0x4c880a747b774fe257a720aa6fce1ab28eddf4d4c6b3277e109d0a92e9f66e29;

    struct Configuration {
        address accessControl;
        TokenGateConfiguration tokenGate;
    }

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__TOKEN_GATED_NAMESPACE_RULE
        }
    }

    constructor() TokenGatedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__SKIP_GATE, "sense.permission.SkipGate");
        TokenGatedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        _validateTokenGateConfiguration(configuration.tokenGate);
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata, /* username */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        _validateTokenBalance(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].tokenGate,
            originalMsgSender
        );
    }

    function _validateTokenBalance(
        address accessControl,
        TokenGateConfiguration memory tokenGateConfiguration,
        address account
    ) internal view {
        if (!accessControl.hasAccess(account, PID__SKIP_GATE)) {
            _validateTokenBalance(tokenGateConfiguration, account);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__TOKEN_GATE) {
                configuration.tokenGate = abi.decode(params[i].value, (TokenGateConfiguration));
            }
        }
        return configuration;
    }
}
