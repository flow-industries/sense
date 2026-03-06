// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {KeyValue, SourceStamp} from "contracts/core/types/Types.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {Errors} from "contracts/core/types/Errors.sol";

abstract contract SourceStampBased is ExtraStorageBased {
    /// @custom:keccak sense.param.sourceStamp
    bytes32 constant PARAM__SOURCE_STAMP = 0x7d066962790e0c91c3f412ba70116f6c31920c114bbeff5e8cf16c59438f34b8;
    /// @custom:keccak sense.data.source
    bytes32 constant DATA__SOURCE = 0x894b42f248ad79490a587f90812b92739d431acca0927cae95260efd773a776c;

    // Functions with generic key

    function _processSourceStamp(bytes32 key, uint256 entityType, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        address source = _processSourceStamp(customParams);
        if (source != address(0)) {
            _storeSource(key, entityType, entityId, source);
        } else {
            _clearSource(key, entityType, entityId);
        }
        return source;
    }

    function _processSourceStamp(KeyValue[] memory customParams) internal returns (address) {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__SOURCE_STAMP) {
                SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
                require(sourceStamp.originalMsgSender == msg.sender, Errors.InvalidSourceStampOriginalMsgSender());
                ISource(sourceStamp.source).validateSource(sourceStamp);
                return sourceStamp.source;
            }
        }
        return address(0);
    }

    function _storeSource(bytes32 key, uint256 entityType, uint256 entityId, address source) internal {
        _setEntityExtraStorage(entityType, entityId, KeyValue(key, abi.encode(source)));
    }

    function _clearSource(bytes32 key, uint256 entityType, uint256 entityId) internal {
        _setEntityExtraStorage(entityType, entityId, KeyValue(key, ""));
    }

    function _getSource(bytes32 key, uint256 entityType, uint256 entityId) internal view returns (address) {
        bytes memory encodedSource = _getEntityExtraStorage(entityType, entityId, key);
        if (encodedSource.length == 0) {
            return address(0);
        } else {
            return abi.decode(encodedSource, (address));
        }
    }

    // Functions with default 0 entityType hardcoded

    function _processSourceStamp(bytes32 key, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        return _processSourceStamp(key, 0, entityId, customParams);
    }

    function _storeSource(bytes32 key, uint256 entityId, address source) internal {
        _storeSource(key, 0, entityId, source);
    }

    function _clearSource(bytes32 key, uint256 entityId) internal {
        _clearSource(key, 0, entityId);
    }

    function _getSource(bytes32 key, uint256 entityId) internal view returns (address) {
        return _getSource(key, 0, entityId);
    }

    // Functions with default `sense.data.source` key hardcoded

    function _processSourceStamp(uint256 entityType, uint256 entityId, KeyValue[] memory customParams)
        internal
        returns (address)
    {
        return _processSourceStamp(DATA__SOURCE, entityType, entityId, customParams);
    }

    function _storeSource(uint256 entityType, uint256 entityId, address source) internal {
        _storeSource(DATA__SOURCE, entityType, entityId, source);
    }

    function _clearSource(uint256 entityType, uint256 entityId) internal {
        _clearSource(DATA__SOURCE, entityType, entityId);
    }

    function _getSource(uint256 entityType, uint256 entityId) internal view returns (address) {
        return _getSource(DATA__SOURCE, entityType, entityId);
    }

    // Functions with default `sense.data.source` key and default 0 entityType hardcoded

    function _processSourceStamp(uint256 entityId, KeyValue[] memory customParams) internal returns (address) {
        return _processSourceStamp(DATA__SOURCE, 0, entityId, customParams);
    }

    function _storeSource(uint256 entityId, address source) internal {
        _storeSource(DATA__SOURCE, 0, entityId, source);
    }

    function _clearSource(uint256 entityId) internal {
        _clearSource(DATA__SOURCE, 0, entityId);
    }

    function _getSource(uint256 entityId) internal view returns (address) {
        return _getSource(DATA__SOURCE, 0, entityId);
    }
}
