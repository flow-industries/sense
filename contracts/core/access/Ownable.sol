// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";

abstract contract Ownable is IOwnable {
    event Sense_Ownable_OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct OwnableStorage {
        address owner;
    }

    /// @custom:keccak sense.storage.Ownable
    bytes32 constant STORAGE__OWNABLE = 0xeb8d4c49f0c28998cc107c90f28f2229359aa289e94e87bee1e40cfa083e80a7;

    function $ownableStorage() private pure returns (OwnableStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__OWNABLE
        }
    }

    modifier onlyOwner() {
        require(msg.sender == $ownableStorage().owner, Errors.InvalidMsgSender());
        _;
    }

    function owner() public view virtual override returns (address) {
        return $ownableStorage().owner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = $ownableStorage().owner;
        $ownableStorage().owner = newOwner;
        emit Sense_Ownable_OwnershipTransferred(oldOwner, newOwner);
    }
}
