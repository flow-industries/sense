// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Membership} from "contracts/core/interfaces/IGroup.sol";
import {Errors} from "contracts/core/types/Errors.sol";

library GroupCore {
    // Storage

    struct Storage {
        uint256 lastMemberIdAssigned;
        uint256 numberOfMembers;
        mapping(address => Membership) memberships;
    }

    /// @custom:keccak sense.storage.GroupCore
    bytes32 constant STORAGE__GROUP_CORE = 0xf4de5e590c0d485ce381c6f1834c5514d951e8c83925c83f03096f68ac7ced39;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__GROUP_CORE
        }
    }

    // Internal functions - Use these functions to be called as an inlined library

    function _isMember(address account) internal view returns (bool) {
        return $storage().memberships[account].id != 0;
    }

    function _getMembership(address account) internal view returns (Membership memory) {
        return $storage().memberships[account];
    }

    function _grantMembership(address account) internal returns (uint256) {
        require(account != address(0), Errors.InvalidParameter());
        uint256 membershipId = ++$storage().lastMemberIdAssigned;
        $storage().numberOfMembers++;
        require($storage().memberships[account].id == 0, Errors.RedundantStateChange()); // Must not be a member yet
        $storage().memberships[account] = Membership(membershipId, block.timestamp);
        return membershipId;
    }

    function _revokeMembership(address account) internal returns (uint256) {
        require(account != address(0), Errors.InvalidParameter());
        uint256 membershipId = $storage().memberships[account].id;
        require(membershipId != 0, Errors.RedundantStateChange()); // Must be a member
        $storage().numberOfMembers--;
        delete $storage().memberships[account];
        return membershipId;
    }
}
