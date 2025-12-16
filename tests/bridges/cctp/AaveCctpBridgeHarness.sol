// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveCctpBridge} from "src/bridges/cctp/AaveCctpBridge.sol";

/// @title AaveCctpBridgeHarness
/// @notice Harness contract to expose internal functions for testing
contract AaveCctpBridgeHarness is AaveCctpBridge {
    constructor(
        address tokenMessenger,
        address usdc,
        uint32 localDomain,
        address owner
    ) AaveCctpBridge(tokenMessenger, usdc, localDomain, owner) {}

    function exposed_addressToBytes32(address addr) external pure returns (bytes32) {
        return _addressToBytes32(addr);
    }
}
