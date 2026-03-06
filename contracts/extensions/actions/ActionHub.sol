// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";

interface IPostAction {
    function configure(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory);

    function execute(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory);

    function setDisabled(
        address originalMsgSender,
        address feed,
        uint256 postId,
        bool isDisabled,
        KeyValue[] calldata params
    ) external payable returns (bytes memory);
}

interface IAccountAction {
    function configure(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory);

    function execute(address originalMsgSender, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory);

    function setDisabled(address originalMsgSender, address account, bool isDisabled, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory);
}

/// @custom:keccak sense.constant.UniversalAction
bytes32 constant UNIVERSAL_ACTION_MAGIC_VALUE = 0xfb23aac554f887d00a0b55a462f08d01bfad5d017b95e060cac76c097744a1bb;

contract ActionHub is SourceStampBased {
    event Sense_ActionHub_PostAction_Universal(address indexed action);

    event Sense_ActionHub_PostAction_Configured(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_PostAction_Reconfigured(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_PostAction_Executed(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_PostAction_Disabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_PostAction_Enabled(
        address indexed action,
        address indexed msgSender,
        address feed,
        uint256 indexed postId,
        address postAuthor,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_AccountAction_Universal(address indexed action);

    event Sense_ActionHub_AccountAction_Configured(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_AccountAction_Reconfigured(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_AccountAction_Executed(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_AccountAction_Disabled(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    event Sense_ActionHub_AccountAction_Enabled(
        address indexed action,
        address indexed msgSender,
        address indexed account,
        address source,
        KeyValue[] params,
        bytes returnData
    );

    /// @custom:keccak sense.storage.ActionHub.PostActionStatus
    bytes32 constant STORAGE__POST_ACTION_STATUS = 0x16750fbf193c3b2a4768480f6dcb791cb606c3a5e60eb10c77fd6c9f3f9717a7;
    /// @custom:keccak sense.storage.ActionHub.AccountActionStatus
    bytes32 constant STORAGE__ACCOUNT_ACTION_STATUS = 0x4a07c05404f55943570089ba1a8f196eb61fbb41857cbb3b01da8a79b5f1671e;

    struct ActionStatus {
        bool wasConfigured;
        bool isDisabled;
    }

    function $postActionStatus()
        internal
        pure
        returns (mapping(address => mapping(address => mapping(uint256 => ActionStatus))) storage _storage)
    {
        assembly {
            _storage.slot := STORAGE__POST_ACTION_STATUS
        }
    }

    function $accountActionStatus()
        internal
        pure
        returns (mapping(address => mapping(address => ActionStatus)) storage _storage)
    {
        assembly {
            _storage.slot := STORAGE__ACCOUNT_ACTION_STATUS
        }
    }

    function signalUniversalPostAction(address action) external payable {
        bytes memory returnData =
            IPostAction(action).configure{value: msg.value}(address(0), address(0), 0, new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE, Errors.UnexpectedContractImpl());
        emit Sense_ActionHub_PostAction_Universal(action);
    }

    function configurePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        bytes memory returnData = IPostAction(action).configure{value: msg.value}(msg.sender, feed, postId, params);
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        if ($postActionStatus()[action][feed][postId].wasConfigured == false) {
            $postActionStatus()[action][feed][postId].wasConfigured = true;
            emit Sense_ActionHub_PostAction_Configured(
                action, msg.sender, feed, postId, postAuthor, source, params, returnData
            );
        } else {
            emit Sense_ActionHub_PostAction_Reconfigured(
                action, msg.sender, feed, postId, postAuthor, source, params, returnData
            );
        }
        return returnData;
    }

    function executePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IPostAction(action).execute{value: msg.value}(msg.sender, feed, postId, params);
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_PostAction_Executed(
            action, msg.sender, feed, postId, postAuthor, source, params, returnData
        );
        return returnData;
    }

    function disablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled == false, Errors.RedundantStateChange());
        bytes memory returnData =
            IPostAction(action).setDisabled{value: msg.value}(msg.sender, feed, postId, true, params);
        $postActionStatus()[action][feed][postId].isDisabled = true;
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_PostAction_Disabled(
            action, msg.sender, feed, postId, postAuthor, source, params, returnData
        );
        return returnData;
    }

    function enablePostAction(address action, address feed, uint256 postId, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($postActionStatus()[action][feed][postId].isDisabled, Errors.RedundantStateChange());
        bytes memory returnData =
            IPostAction(action).setDisabled{value: msg.value}(msg.sender, feed, postId, false, params);
        $postActionStatus()[action][feed][postId].isDisabled = false;
        address postAuthor = IFeed(feed).getPostAuthor(postId);
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_PostAction_Enabled(action, msg.sender, feed, postId, postAuthor, source, params, returnData);
        return returnData;
    }

    function signalUniversalAccountAction(address action) external payable {
        bytes memory returnData =
            IAccountAction(action).configure{value: msg.value}(address(0), address(0), new KeyValue[](0));
        require(abi.decode(returnData, (bytes32)) == UNIVERSAL_ACTION_MAGIC_VALUE, Errors.UnexpectedContractImpl());
        emit Sense_ActionHub_AccountAction_Universal(action);
    }

    function configureAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IAccountAction(action).configure{value: msg.value}(msg.sender, account, params);
        address source = _processSourceStamp(params);
        if ($accountActionStatus()[action][account].wasConfigured == false) {
            $accountActionStatus()[action][account].wasConfigured = true;
            emit Sense_ActionHub_AccountAction_Configured(action, msg.sender, account, source, params, returnData);
        } else {
            emit Sense_ActionHub_AccountAction_Reconfigured(action, msg.sender, account, source, params, returnData);
        }
        return returnData;
    }

    function executeAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.Disabled());
        bytes memory returnData = IAccountAction(action).execute{value: msg.value}(msg.sender, account, params);
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_AccountAction_Executed(action, msg.sender, account, source, params, returnData);
        return returnData;
    }

    function disableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled == false, Errors.RedundantStateChange());
        bytes memory returnData = IAccountAction(action).setDisabled{value: msg.value}(msg.sender, account, true, params);
        $accountActionStatus()[action][account].isDisabled = true;
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_AccountAction_Disabled(action, msg.sender, account, source, params, returnData);
        return returnData;
    }

    function enableAccountAction(address action, address account, KeyValue[] calldata params)
        external
        payable
        returns (bytes memory)
    {
        require($accountActionStatus()[action][account].isDisabled, Errors.RedundantStateChange());
        bytes memory returnData =
            IAccountAction(action).setDisabled{value: msg.value}(msg.sender, account, false, params);
        $accountActionStatus()[action][account].isDisabled = false;
        address source = _processSourceStamp(params);
        emit Sense_ActionHub_AccountAction_Enabled(action, msg.sender, account, source, params, returnData);
        return returnData;
    }
}
