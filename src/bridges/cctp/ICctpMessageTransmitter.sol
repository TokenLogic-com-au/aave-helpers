// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICctpMessageTransmitter {
  function receiveMessage(
    bytes calldata message,
    bytes calldata attestation
  ) external returns (bool success);
}
