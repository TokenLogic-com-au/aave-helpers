// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICcipGhoBridge {
  enum PayFeesIn {
    Native,
    LINK
  }

  struct Transfer {
    address to;
    uint256 amount;
  }

  function transfer(
    uint64 destinationChainSelector,
    Transfer[] calldata transfers,
    PayFeesIn payFeesIn
  ) external payable returns (bytes32 messageId);

  event TransferIssued(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    uint256 totalAmount
  );
  event TransferFinished(bytes32 indexed messageId);
  event DestinationUpdated(uint64 indexed chainSelector, address indexed bridge);

  error UnsupportChain();
  error InsufficientFee();
  error InvalidTransferAmount();
  error InvalidMessage();
}
