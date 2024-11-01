// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveCcipGhoBridge {
  /**
   * @dev Emits when a new token transfer is issued
   * @param messageId The ID of the cross-chain message
   * @param destinationChainSelector The selector of the destination chain
   *        chain selector can be found https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet
   * @param amount The total amount of GHO tokens
   */
  event TransferIssued(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    uint256 amount
  );

  /**
   * @dev Emits when the token transfer is executed on the destination chain
   * @param messageId The ID of the cross-chain message
   * @param from The address of sender on source chain
   * @param to The address of receiver on destination chain
   * @param amount The amount of token to translated
   */
  event TransferFinished(
    bytes32 indexed messageId,
    address indexed from,
    address indexed to,
    uint256 amount
  );

  /**
   * @dev Emits when the destination bridge data is updated
   * @param chainSelector The selector of the destination chain
   * @param bridge The address of the bridge on the destination chain
   */
  event DestinationUpdated(uint64 indexed chainSelector, address indexed bridge);

  /// @dev Returns this error when the destination chain is not set up
  error UnsupportedChain();

  /// @dev Returns this error when the native fee amount is below the required amount
  error InsufficientFee();

  /// @dev Returns this error when the total amount is zero
  error InvalidTransferAmount();

  /// @dev Returns this error when the message comes from an invalid bridge
  error InvalidMessage();

  /// @dev Returns this error when fund transfer to sender returns error
  error FundTransferBackFailed();

  /// @dev Returns this error when fee token is not supported
  /// @param token The address of invalid token
  error NotAFeeToken(address token);

  /**
   * @notice Transfers tokens to the destination chain and distributes them
   * @param destinationChainSelector The selector of the destination chain
   *        chain selector can be found https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet
   * @param amount The amount to transfer
   * @param feeToken The address of payment token
   * @return messageId The ID of the cross-chain message
   */
  function transfer(
    uint64 destinationChainSelector,
    uint256 amount,
    address feeToken
  ) external payable returns (bytes32 messageId);

  /**
   * @notice calculates fee amount to exeucte transfers
   * @param destinationChainSelector The selector of the destination chain
   *        chain selector can be found https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet
   * @param amount The amount to transfer
   * @param feeToken The address of payment token
   * @return fee The amount of fee
   */
  function quoteTransfer(
    uint64 destinationChainSelector,
    uint256 amount,
    address feeToken
  ) external view returns (uint256 fee);
}
