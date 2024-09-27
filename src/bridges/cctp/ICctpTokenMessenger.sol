// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICctpTokenMessenger {
  function depositForBurn(
    uint256 amount,
    uint32 destinationDomain,
    bytes32 mintRecipient,
    address burnToken
  ) external returns (uint64);
}
