// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

abstract contract TrustBasedRule {
    event Sense_Rule_Trusted(address indexed account, address indexed trustedAddress);
    event Sense_Rule_Untrusted(address indexed account, address indexed untrustedAddress);

    /// @custom:keccak sense.storage.TrustBasedRule.isTrusted
    bytes32 constant STORAGE__IS_TRUSTED = 0xf8a2a247a350dfb01827b367489c01f44e203bea3b996c63651e4e7e438a4210;

    function $isTrusted() private pure returns (mapping(address => mapping(address => bool)) storage _storage) {
        assembly {
            _storage.slot := STORAGE__IS_TRUSTED
        }
    }

    function setTrust(address target, bool isTrusted) external virtual {
        $isTrusted()[msg.sender][target] = isTrusted;
        if (isTrusted) {
            emit Sense_Rule_Trusted(msg.sender, target);
        } else {
            emit Sense_Rule_Untrusted(msg.sender, target);
        }
    }

    function _requireTrust(address fromAccount, address toTarget) internal view virtual {
        require(_isTrusted(fromAccount, toTarget), Errors.Untrusted());
    }

    function _isTrusted(address fromAccount, address toTarget) internal view virtual returns (bool) {
        return $isTrusted()[fromAccount][toTarget];
    }
}
