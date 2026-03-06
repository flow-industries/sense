// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {OwnableMetadataBasedPostAction} from "contracts/actions/post/base/OwnableMetadataBasedPostAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {SensePaymentHandler} from "contracts/extensions/fees/SensePaymentHandler.sol";

contract TippingPostAction is SensePaymentHandler, OwnableMetadataBasedPostAction, Initializable {
    using SafeERC20 for IERC20;

    /// @custom:keccak sense.param.amount
    bytes32 constant PARAM__TIP_AMOUNT = 0xeaa3dd19eab22ecc64759d4cd79f6f6e9243d88ba532ea00ded4283b5ad9ae6e;
    /// @custom:keccak sense.param.token
    bytes32 constant PARAM__TIP_TOKEN = 0x2779023769d78afea1ea6190f63ff520931d95692776fa9186e2a883072b8e44;
    /// @custom:keccak sense.param.referrals
    bytes32 constant PARAM__REFERRALS = 0xe101986198b5c30a6ffb015105ee63311b35d0a2d7768694589fc3d6dc5ba469;

    uint16 constant REFERRALS_FEE_MAX_BPS = 2000; // 20.00%

    constructor(address actionHub) OwnableMetadataBasedPostAction(actionHub, address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedPostAction._initialize(owner, metadataURI);
    }

    function _execute(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        internal
        override
        returns (bytes memory)
    {
        address erc20Token;
        uint256 tipAmount;
        RecipientData[] memory referrals = new RecipientData[](0);
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__TIP_AMOUNT) {
                tipAmount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == PARAM__TIP_TOKEN) {
                erc20Token = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__REFERRALS) {
                referrals = abi.decode(params[i].value, (RecipientData[]));
            }
        }
        require(tipAmount > 0, Errors.InvalidParameter());
        address account = IFeed(feed).getPostAuthor(postId);
        _handlePayment({
            payer: originalMsgSender,
            token: erc20Token,
            amount: tipAmount,
            recipient: account,
            referrals: referrals,
            referralFeeBps: REFERRALS_FEE_MAX_BPS
        });
        return abi.encode(account);
    }
}
