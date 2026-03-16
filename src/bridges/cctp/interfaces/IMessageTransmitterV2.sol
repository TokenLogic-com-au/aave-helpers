// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IMessageTransmitterV2
/// @notice Minimal interface for Circle's CCTP V2 MessageTransmitter contract
interface IMessageTransmitterV2 {
  function localDomain() external view returns (uint32);
}
