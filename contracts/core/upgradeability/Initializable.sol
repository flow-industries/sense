// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

abstract contract Initializable {
    // Storage

    struct InitializableStorage {
        bool initialized;
    }

    /// @custom:keccak sense.storage.Initializable
    bytes32 constant STORAGE__INITIALIZABLE = 0x3805ec31188b48de19b24fe807be883cdf9143a448aec45b97c9b6c1ecb14e9d;

    function $initializableStorage() internal pure returns (InitializableStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__INITIALIZABLE
        }
    }

    modifier initializer() {
        require(!$initializableStorage().initialized, Errors.AlreadyInitialized());
        $initializableStorage().initialized = true;
        _;
    }

    function _disableInitializers() internal virtual {
        $initializableStorage().initialized = true;
    }
}
