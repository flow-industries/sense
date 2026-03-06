// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";

library NamespaceCore {
    // Storage

    struct Storage {
        string namespace;
        mapping(string => bool) usernameExists;
        mapping(string => address) usernameToAccount;
        mapping(address => string) accountToUsername;
    }

    /// @custom:keccak sense.storage.NamespaceCore
    bytes32 constant STORAGE__NAMESPACE_CORE = 0xc0859b09b5c609ba4c029fd0c4e06efbf38db2535eca3140b5ecd4f873425d89;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__NAMESPACE_CORE
        }
    }

    // Internal functions

    function _createUsername(string memory username) internal {
        require(!$storage().usernameExists[username], Errors.AlreadyExists()); // Username must not exist yet
        require(bytes(username).length > 0, Errors.InvalidParameter()); // Username must not be empty
        require(bytes(username).length < type(uint8).max, Errors.InvalidParameter()); // Length must be less than 255
        $storage().usernameExists[username] = true;
    }

    function _removeUsername(string memory username) internal {
        require($storage().usernameExists[username], Errors.DoesNotExist()); // Username must exist
        require($storage().usernameToAccount[username] == address(0), Errors.UsernameAssigned()); // Username must not be assigned
        $storage().usernameExists[username] = false;
    }

    function _assignUsername(address account, string memory username) internal {
        require($storage().usernameExists[username], Errors.DoesNotExist()); // Username must exist
        require($storage().usernameToAccount[username] == address(0), Errors.UsernameAssigned()); // Username must not be assigned yet
        require(bytes($storage().accountToUsername[account]).length == 0, Errors.UsernameAssigned()); // Account must not have a username yet
        $storage().usernameToAccount[username] = account;
        $storage().accountToUsername[account] = username;
    }

    function _unassignUsername(string memory username) internal {
        address account = $storage().usernameToAccount[username];
        require(account != address(0), Errors.RedundantStateChange()); // Username must be assigned
        delete $storage().accountToUsername[account];
        delete $storage().usernameToAccount[username];
    }
}
