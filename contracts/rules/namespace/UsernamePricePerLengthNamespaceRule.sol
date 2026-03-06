// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {INamespaceRule} from "contracts/core/interfaces/INamespaceRule.sol";
import {AccessControlLib} from "contracts/core/libraries/AccessControlLib.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SimplePaymentRule} from "contracts/rules/base/SimplePaymentRule.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {BPS_MAX} from "contracts/core/types/Constants.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract UsernamePricePerLengthNamespaceRule is SimplePaymentRule, Initializable, INamespaceRule {
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
    /// @custom:keccak sense.param.pricePerLengthConfig
    bytes32 constant PARAM__PRICE_PER_LENGTH = 0x47db35d797c0b548423f3fbc43b4cb78921a333cfefddff5a4352b47563d2b77;

    /// @custom:keccak sense.storage.UsernamePricePerLengthNamespaceRule
    bytes32 constant STORAGE__USERNAME_PRICE_PER_LENGTH_NAMESPACE_RULE =
        0xaa2992940c74cd9846b0ad6e33afae3ca084465e4e74c5ae766bd6bc4dd423a7;

    struct Configuration {
        address accessControl;
        uint16 referralFeeBps;
        PaymentConfiguration defaultConfig;
        mapping(uint256 => Price) pricePerLength;
    }

    struct LengthPriceConfig {
        bool setCustomPrice;
        uint256 length;
        uint256 price;
    }

    struct Price {
        bool isSet;
        uint256 price;
    }

    struct Storage {
        mapping(address namespace => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__USERNAME_PRICE_PER_LENGTH_NAMESPACE_RULE
        }
    }

    constructor() SimplePaymentRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        emit Events.Sense_PermissionId_Available(PID__SKIP_PAYMENT, "sense.permission.SkipPayment");
        SimplePaymentRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleConfigurationParams) external override {
        _extractAndSaveConfigurationFromParams(configSalt, ruleConfigurationParams);
        $storage().configuration[msg.sender][configSalt].accessControl.verifyHasAccessFunction();
        require($storage().configuration[msg.sender][configSalt].referralFeeBps <= BPS_MAX, Errors.InvalidParameter());
        _validatePaymentConfiguration($storage().configuration[msg.sender][configSalt].defaultConfig);
    }

    function processCreation(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processRemoval(
        bytes32 configSalt,
        address originalMsgSender,
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processAssigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function processUnassigning(
        bytes32 configSalt,
        address originalMsgSender,
        address, /* account */
        string calldata username,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata ruleParams
    ) external override {
        _processPayment(
            configSalt,
            originalMsgSender,
            username,
            _extractPaymentConfigurationFromParams(ruleParams),
            _extractReferralsFromParams(ruleParams)
        );
    }

    function _processPayment(
        bytes32 configSalt,
        address payer,
        string calldata username,
        PaymentConfiguration memory expectedPaymentConfiguration,
        RecipientData[] memory referrals
    ) internal {
        PaymentConfiguration memory paymentConfiguration = $storage().configuration[msg.sender][configSalt].defaultConfig;
        Price memory pricePerLength =
            $storage().configuration[msg.sender][configSalt].pricePerLength[bytes(username).length];
        if (pricePerLength.isSet) {
            paymentConfiguration.amount = pricePerLength.price;
        }
        if (!$storage().configuration[msg.sender][configSalt].accessControl.hasAccess(payer, PID__SKIP_PAYMENT)) {
            _processPayment(
                paymentConfiguration,
                expectedPaymentConfiguration,
                payer,
                referrals,
                $storage().configuration[msg.sender][configSalt].referralFeeBps
            );
        }
    }

    function _extractAndSaveConfigurationFromParams(bytes32 configSalt, KeyValue[] calldata params) internal {
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__ACCESS_CONTROL) {
                $storage().configuration[msg.sender][configSalt].accessControl = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__PAYMENT_CONFIG) {
                $storage().configuration[msg.sender][configSalt].defaultConfig =
                    abi.decode(params[i].value, (PaymentConfiguration));
            } else if (params[i].key == PARAM__REFERRAL_FEE) {
                $storage().configuration[msg.sender][configSalt].referralFeeBps = abi.decode(params[i].value, (uint16));
            } else if (params[i].key == PARAM__PRICE_PER_LENGTH) {
                LengthPriceConfig[] memory pricePerLengthConfig = abi.decode(params[i].value, (LengthPriceConfig[]));
                for (uint256 j = 0; j < pricePerLengthConfig.length; j++) {
                    $storage().configuration[msg.sender][configSalt].pricePerLength[pricePerLengthConfig[j].length] =
                        Price({isSet: pricePerLengthConfig[j].setCustomPrice, price: pricePerLengthConfig[j].price});
                }
            }
        }
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

    function _validatePaymentConfiguration(PaymentConfiguration memory configuration) internal view virtual override {
        _validateToken(configuration.token);
    }
}
