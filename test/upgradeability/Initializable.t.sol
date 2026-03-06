// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Initializable} from "@core/upgradeability/Initializable.sol";
import {Errors} from "@core/types/Errors.sol";

contract InitializableContract is Initializable {
    function initialize() public initializer {
        return;
    }
}

contract InitializableTest is Test {
    /// @custom:keccak sense.storage.Initializable
    bytes32 constant STORAGE__INITIALIZABLE = 0x3805ec31188b48de19b24fe807be883cdf9143a448aec45b97c9b6c1ecb14e9d;

    bytes32 constant TRUE = bytes32(uint256(1));
    bytes32 constant FALSE = bytes32(uint256(0));

    InitializableContract initializable;

    function setUp() public virtual {
        initializable = new InitializableContract();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_Initialize() public {
        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), FALSE);

        initializable.initialize();

        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), TRUE);
    }

    function test_Cannot_InitializeTwice() public {
        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), FALSE);

        initializable.initialize();

        assertEq(vm.load(address(initializable), STORAGE__INITIALIZABLE), TRUE);

        vm.expectRevert(Errors.AlreadyInitialized.selector);
        initializable.initialize();
    }
}
