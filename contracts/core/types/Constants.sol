// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

// 100.00% represented as Basis Points, each Basis Point is 0.01%
uint256 constant BPS_MAX = 10_000;

uint256 constant SELECTOR_BYTE_LENGTH = 4;

/// @custom:keccak sense.contract.ActionHub
bytes32 constant CONTRACT__ACTION_HUB = 0xb14c0376d1d350382758937d3867a0fffc133ddd01ff7e04bf20b7641ad2c878;

/// @custom:keccak sense.contract.SenseFees
bytes32 constant CONTRACT__SENSE_FEES = 0xc8979bd17d868644aa47952765548e9b7cb27cc4546bcc8d4a6ae8ea7cfe5b95;

/// @custom:keccak sense.contract.SenseNativePaymentHelper
bytes32 constant CONTRACT__SENSE_NATIVE_PAYMENT_HELPER =
    0x1d7fe158e9ead9a15a449e23da505e07f039ac8f3252b8ad41517f94753b545a;

address constant NATIVE_TOKEN = address(0x800A);
