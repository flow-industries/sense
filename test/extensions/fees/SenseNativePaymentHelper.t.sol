// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./../../helpers/TypeHelpers.sol";

import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {FuzzZkTest} from "test/helpers/FuzzZkTest.sol";
import {Errors} from "@core/types/Errors.sol";
import {SenseNativePaymentHelper} from "@extensions/fees/SenseNativePaymentHelper.sol";

contract SenseNativePaymentHelperTest is FuzzZkTest, BaseDeployments {
    function setUp() public override {
        super.setUp();

        senseNativePaymentHelper = payable(new SenseNativePaymentHelper());
    }

    function test_SenseNativePaymentHelper_CanReceiveFunds(uint256 msgValue) public {
        msgValue = _boundAmount(msgValue);
        vm.deal(address(this), msgValue);

        assertEq(address(senseNativePaymentHelper).balance, 0);

        (bool callSucceeded,) = address(senseNativePaymentHelper).call{value: msgValue}("");
        assertTrue(callSucceeded);

        assertEq(address(senseNativePaymentHelper).balance, msgValue);
    }

    function test_SenseNativePaymentHelper_CanTransferFundsToAddress(uint256 initialValue, uint256 transferAmount)
        public
    {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmount(transferAmount);
        vm.assume(transferAmount <= initialValue);

        (bool callSucceeded,) = address(senseNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        assertEq(address(senseNativePaymentHelper).balance, initialValue);

        address receiver = makeAddr("RECEIVER");

        vm.assume(receiver.balance == 0);

        SenseNativePaymentHelper(senseNativePaymentHelper).transferNative(receiver, transferAmount);

        assertEq(receiver.balance, transferAmount);
        assertEq(address(senseNativePaymentHelper).balance, initialValue - transferAmount);
    }

    function test_SenseNativePaymentHelper_RevertsIfTransferAmountIsGreaterThanBalance(
        uint256 initialValue,
        uint256 transferAmount
    ) public {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmount(transferAmount);
        vm.assume(transferAmount > initialValue);

        (bool callSucceeded,) = address(senseNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        vm.expectRevert(Errors.NotEnoughBalance.selector);
        SenseNativePaymentHelper(senseNativePaymentHelper).transferNative(address(this), transferAmount);
    }

    function test_SenseNativePaymentHelper_CanRefundNative(uint256 initialValue, uint256 transferAmount) public {
        initialValue = _boundAmount(initialValue);
        vm.deal(address(this), initialValue);
        transferAmount = _boundAmountAllowZero(transferAmount);
        vm.assume(transferAmount <= initialValue);

        (bool callSucceeded,) = address(senseNativePaymentHelper).call{value: initialValue}("");
        assertTrue(callSucceeded);

        assertEq(address(senseNativePaymentHelper).balance, initialValue);

        address receiver = makeAddr("RECEIVER");

        vm.assume(receiver.balance == 0);

        SenseNativePaymentHelper(senseNativePaymentHelper).transferNative(receiver, transferAmount);

        assertEq(receiver.balance, transferAmount);
        assertEq(address(senseNativePaymentHelper).balance, initialValue - transferAmount);

        SenseNativePaymentHelper(senseNativePaymentHelper).refundNative(receiver);

        assertEq(address(senseNativePaymentHelper).balance, 0);
        assertEq(receiver.balance, initialValue);
    }
}
