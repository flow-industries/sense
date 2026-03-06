// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {UNIVERSAL_ACTION_MAGIC_VALUE} from "contracts/extensions/actions/ActionHub.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract BaseAction {
    address immutable ACTION_HUB;

    /// @custom:keccak sense.storage.Action.configured
    bytes32 constant STORAGE__ACTION_CONFIGURED = 0xc34061333567c7fe551ec11e2c0831b1687f1353e81f3ef4af3f3d9a07e291ff;

    modifier onlyActionHub() {
        require(msg.sender == ACTION_HUB, Errors.InvalidMsgSender());
        _;
    }

    constructor(address actionHub) {
        ACTION_HUB = actionHub;
    }

    function _configureUniversalAction(address originalMsgSender) internal onlyActionHub returns (bytes memory) {
        bool configured;
        assembly {
            configured := sload(STORAGE__ACTION_CONFIGURED)
        }
        require(!configured, Errors.RedundantStateChange());
        require(originalMsgSender == address(0), Errors.InvalidParameter());
        assembly {
            sstore(STORAGE__ACTION_CONFIGURED, 1)
        }
        return abi.encode(UNIVERSAL_ACTION_MAGIC_VALUE);
    }
}
