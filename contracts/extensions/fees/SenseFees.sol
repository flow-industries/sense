// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

struct SenseFeesData {
    address treasuryAddress;
    uint16 treasuryFeeBps;
}

interface ISenseFees {
    function getTreasuryAddress() external view returns (address);

    function getTreasuryFeeBps() external view returns (uint16);

    function getSenseFeesData() external view returns (SenseFeesData memory);
}

contract SenseFees is ISenseFees {
    address internal immutable SENSE_TREASURY_ADDRESS;
    uint16 internal immutable SENSE_TREASURY_FEE_BPS;

    constructor(address treasuryAddress, uint16 treasuryFeeBps) {
        SENSE_TREASURY_ADDRESS = treasuryAddress;
        SENSE_TREASURY_FEE_BPS = treasuryFeeBps;
    }

    function getTreasuryAddress() external view override returns (address) {
        return SENSE_TREASURY_ADDRESS;
    }

    function getTreasuryFeeBps() external view override returns (uint16) {
        return SENSE_TREASURY_FEE_BPS;
    }

    function getSenseFeesData() external view override returns (SenseFeesData memory) {
        return SenseFeesData(SENSE_TREASURY_ADDRESS, SENSE_TREASURY_FEE_BPS);
    }
}
