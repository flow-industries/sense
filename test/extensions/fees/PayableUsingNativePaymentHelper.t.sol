// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./../../helpers/TypeHelpers.sol";

import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";
import {PayableUsingNativePaymentHelper} from "@extensions/fees/SenseNativePaymentHelper.sol";
import {ISenseCreate2, SENSE_CREATE_2_ADDRESS} from "@core/upgradeability/SenseCreate2.sol";
import {CONTRACT__SENSE_NATIVE_PAYMENT_HELPER} from "@core/types/Constants.sol";
import {Errors} from "@core/types/Errors.sol";

contract PayableUsingNativePaymentHelperTest is FuzzZkTest, BaseDeployments {
    function setUp() public override {
        super.setUp();

        senseNativePaymentHelper =
            payable(ISenseCreate2(SENSE_CREATE_2_ADDRESS).getAddress(CONTRACT__SENSE_NATIVE_PAYMENT_HELPER));
    }

    function test_PayableUsingNativePaymentHelper_SendsMsgValueToNativePaymentHelper(uint256 msgValue) public {
        msgValue = _boundAmount(msgValue);
        vm.deal(address(this), msgValue);

        DummyPayableUsingNativePaymentHelper payableUsingNativePaymentHelper = new DummyPayableUsingNativePaymentHelper();

        assertEq(senseNativePaymentHelper.balance, 0);

        payableUsingNativePaymentHelper.somePayableFunction{value: msgValue}();

        assertEq(senseNativePaymentHelper.balance, msgValue);
    }

    function test_PayableUsingNativePaymentHelper_RevertsIfSpendSomeMsgValueFails(uint256 msgValue) public {
        msgValue = _boundAmount(msgValue);
        vm.deal(address(this), msgValue);

        RevertingPayableUsingNativePaymentHelper payableUsingNativePaymentHelper =
            new RevertingPayableUsingNativePaymentHelper();

        assertEq(senseNativePaymentHelper.balance, 0);

        vm.expectRevert(Errors.FailedToTransferNative.selector);
        payableUsingNativePaymentHelper.somePayableFunction{value: msgValue}();

        assertEq(senseNativePaymentHelper.balance, 0);
    }
}

contract DummyPayableUsingNativePaymentHelper is PayableUsingNativePaymentHelper {
    function somePayableFunction() public payable usingNativePaymentHelper {
        return;
    }
}

contract RevertingPayableUsingNativePaymentHelper is PayableUsingNativePaymentHelper {
    modifier spendSomeMsgValue() {
        if (msg.value > 0) {
            (bool callSucceeded,) = address(0).call{value: 1}("");
            require(callSucceeded);
        }
        _;
    }

    function somePayableFunction() public payable spendSomeMsgValue usingNativePaymentHelper {
        return;
    }
}
