// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {NATIVE_TOKEN, BPS_MAX} from "contracts/core/types/Constants.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {ActionHub} from "contracts/extensions/actions/ActionHub.sol";

/// @custom:keccak sense.param.amount
bytes32 constant PARAM__TIP_AMOUNT = 0xeaa3dd19eab22ecc64759d4cd79f6f6e9243d88ba532ea00ded4283b5ad9ae6e;
/// @custom:keccak sense.param.token
bytes32 constant PARAM__TIP_TOKEN = 0x2779023769d78afea1ea6190f63ff520931d95692776fa9186e2a883072b8e44;

contract TippingAccountActionTest is Test, BaseDeployments {
    function setUp() public override {
        super.setUp();
    }

    function testCanAccountTipNative_woReferrals(uint256 msgValue, address account) public {
        vm.assume(account != address(0));
        vm.assume(account != address(TREASURY_ADDRESS));
        vm.assume(account.code.length == 0);
        vm.assume(uint160(account) > type(uint16).max); // skip system contracts
        assumeNotForgeAddress(account);

        msgValue = msgValue % (1 << 95);
        vm.assume(msgValue > 0);
        vm.deal(address(this), msgValue);

        KeyValue[] memory params = _toKeyValueArray(
            KeyValue({key: PARAM__TIP_AMOUNT, value: abi.encode(msgValue)}),
            KeyValue({key: PARAM__TIP_TOKEN, value: abi.encode(NATIVE_TOKEN)})
        );

        uint256 accountBalanceBefore = account.balance;
        uint256 treasuryBalanceBefore = address(TREASURY_ADDRESS).balance;

        ActionHub(actionHub).executeAccountAction{value: msgValue}(address(tippingAccountAction), account, params);

        uint256 accountBalanceAfter = account.balance;
        uint256 treasuryBalanceAfter = address(TREASURY_ADDRESS).balance;

        uint256 expectedTreasuryBalanceChange = msgValue * TREASURY_FEE_BPS / BPS_MAX;
        uint256 expectedAccountBalanceChange = msgValue - expectedTreasuryBalanceChange;

        assertEq(accountBalanceAfter, accountBalanceBefore + expectedAccountBalanceChange, "Account balance mismatch");
        assertEq(
            treasuryBalanceAfter, treasuryBalanceBefore + expectedTreasuryBalanceChange, "Treasury balance mismatch"
        );
    }
}
