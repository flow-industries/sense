// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Events} from "contracts/core/types/Events.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {BPS_MAX} from "contracts/core/types/Constants.sol";

contract SimplePaymentGroupRule is SimplePaymentRule, Initializable, IGroupRule {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    /// @custom:keccak sense.permission.SkipPayment
    uint256 constant PID__SKIP_PAYMENT = uint256(0x3d2561fc4fb84b50403ba25bbac5deca4d160044709aa895c8888af5dc5707be);

    /// @custom:keccak sense.param.accessControl
    bytes32 constant PARAM__ACCESS_CONTROL = 0x60bed11e4162e3e9bcfb8044458f295705a04aa845c92624582efb6c988f9b9e;
    /// @custom:keccak sense.param.referrals
    bytes32 constant PARAM__REFERRALS = 0xe101986198b5c30a6ffb015105ee63311b35d0a2d7768694589fc3d6dc5ba469;
    /// @custom:keccak sense.param.referralFee
    bytes32 constant PARAM__REFERRAL_FEE = 0x572859a2dfb962d4fd0391f169e5e52f8a5fdf3edd1e793981e717e9c443039f;

    /// @custom:keccak sense.storage.SimplePaymentGroupRule
    bytes32 constant STORAGE__SIMPLE_PAYMENT_GROUP_RULE =
        0x0dc3e7256a6ba71f4268b2d92c149e92e43486fb50d8222ecaf24303ec0b9bb3;

    struct Configuration {
        address accessControl;
        uint16 referralFeeBps;
        PaymentConfiguration paymentConfiguration;
    }

    struct Storage {
        mapping(address group => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__SIMPLE_PAYMENT_GROUP_RULE
        }
    }

    constructor() SimplePaymentRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__SKIP_PAYMENT, "sense.permission.SkipPayment");
        SimplePaymentRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration = _extractConfigurationFromParams(ruleParams);
        configuration.accessControl.verifyHasAccessFunction();
        require(configuration.referralFeeBps <= BPS_MAX, Errors.InvalidParameter());
        _validatePaymentConfiguration(configuration.paymentConfiguration);
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processAddition(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            originalMsgSender,
            _extractReferralsFromParams(ruleParams),
            $storage().configuration[msg.sender][configSalt].referralFeeBps
        );
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
        bytes32 configSalt,
        address account,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            $storage().configuration[msg.sender][configSalt].accessControl,
            $storage().configuration[msg.sender][configSalt].paymentConfiguration,
            _extractPaymentConfigurationFromParams(ruleParams),
            account,
            _extractReferralsFromParams(ruleParams),
            $storage().configuration[msg.sender][configSalt].referralFeeBps
        );
    }

    function processLeaving(
        bytes32, /* configSalt */
        address, /* account */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function _processPayment(
        address accessControl,
        PaymentConfiguration memory paymentConfiguration,
        PaymentConfiguration memory expectedPaymentConfiguration,
        address payer,
        RecipientData[] memory referrals,
        uint16 referralFeeBps
    ) internal {
        if (!accessControl.hasAccess(payer, PID__SKIP_PAYMENT)) {
            _processPayment(paymentConfiguration, expectedPaymentConfiguration, payer, referrals, referralFeeBps);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params) internal pure returns (Configuration memory) {
        Configuration memory configuration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                configuration.accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__REFERRAL_FEE) {
                configuration.referralFeeBps = abi.decode(params[i].value, (uint16));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                configuration.paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
            }
        }
        return configuration;
    }

    function _extractPaymentConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (PaymentConfiguration memory)
    {
        PaymentConfiguration memory paymentConfiguration;
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__PAYMENT_CONFIG) {
                paymentConfiguration = abi.decode(params[i].value, (PaymentConfiguration));
                break;
            }
        }
        return paymentConfiguration;
    }

    function _extractReferralsFromParams(KeyValue[] calldata params) internal pure returns (RecipientData[] memory) {
        RecipientData[] memory referrals = new RecipientData[](0);
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__REFERRALS) {
                referrals = abi.decode(params[i].value, (RecipientData[]));
                break;
            }
        }
        return referrals;
    }
}
