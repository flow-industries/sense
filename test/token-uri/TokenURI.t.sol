// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SenseUsernameTokenURIProvider} from "contracts/core/primitives/namespace/SenseUsernameTokenURIProvider.sol";
import {IERC721Namespace} from "contracts/core/interfaces/IERC721Namespace.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract TokenURITest is Test {
    using StringsUpgradeable for uint256;

    SenseUsernameTokenURIProvider uriProvider;

    function setUp() public {
        uriProvider = new SenseUsernameTokenURIProvider();
    }

    function testW() public {
        for (uint256 i = 1; i < 70; i++) {
            _testSingleCase("sense", _getUsername(i));
        }
    }

    function testSingleCase() public {
        _testSingleCase("sense", "satoshi");
        _testSingleCase("sense", "stani");
        _testSingleCase("sense", "donosonaumczuk");
        _testSingleCase("sense", "sense");
        _testSingleCase("sense", "averylongusernamehahahawellmaybenotthatlong");
        _testSingleCase("orb", "jordan");
        _testSingleCase("orb", "customer23");
        _testSingleCase("somelongerapp", "vitalik");
        _testSingleCase("somelongerapp", "im_alan");
        _testSingleCase("somelongerapp", "hellokitty");
        _testSingleCase("somelongerapp", "hellokitty");
        _testSingleCase("wwwwwwwwwwwwwwww", "longbutgoeswell");
        _testSingleCase("wwwwwwwwwwwwwwwww", "longbutgoeswell");
        _testSingleCase("wwwwwwwwwwwwwwwwww", "longbutgoeswell");
        _testSingleCase("wwwwwwwwwwwwwwwwwww", "toolongtofit");
        _testSingleCase("but19otherchars12345", "gowell");
        _testSingleCase("myes<ape", "some&injecti>n");
        _testSingleCase("o'connor", 'double"quotes');
        _testSingleCase("wwwwwwwwwwwwwwww>>w", "toolongtofit");
        _testSingleCase("UpperC4se", "c0nVERSiOn");
        _testSingleCase("CAPITALIZATION", "TEST2");
        _testSingleCase('UPPERcaS"e', "withSomeJsonToEscape");
    }

    function _testSingleCase(string memory namespace, string memory username) internal {
        address caller = address(0xc0ffee);

        vm.mockCall(caller, abi.encodeWithSelector(INamespace.getNamespace.selector), abi.encode(namespace));

        vm.mockCall(caller, abi.encodeWithSelector(IERC721Namespace.getUsernameByTokenId.selector), abi.encode(username));

        vm.prank(caller);
        string memory tokenUriReturned = uriProvider.tokenURI(0);

        // vm.writeFile(string.concat("./svg-output/", namespace, "___", username, ".base64"), tokenUriReturned);

        string memory expectedTokenUri =
            vm.readFile(string.concat("./test/token-uri/expected-svgs/", namespace, "___", username, ".base64"));

        assertEq(expectedTokenUri, tokenUriReturned);
    }

    function _slice(string memory str, uint256 start, uint256 end) internal pure virtual returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }

    function _getUsername(uint256 n) internal pure virtual returns (string memory) {
        // get n w's in a row
        string memory w = new string(n);
        for (uint256 i = 0; i < n; i++) {
            bytes(w)[i] = "w";
        }
        return w;
    }
}
