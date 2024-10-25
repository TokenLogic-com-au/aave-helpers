// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveCctpBridge {
  /// @notice Emitted when new bridge message sent
  event BridgeMessageSent(uint32 toChainId, uint256 amount);
  /// @notice Emitted when redeem token on receiving chain
  event BridgeMessageReceived(bytes message);
  /// @notice Emitted when collector address updated
  event CollectorUpdated(uint32 toChainId, address collector);

  /// @notice This function is not supported on this chain
  error InvalidChain();

  /// @notice Amount is zero
  error ZeroAmount();

  /**
   * @notice The amount of tokens is insufficient.
   * @param amount Current amount of token
   */
  error InsufficientBalance(uint256 amount);

  /**
   * @notice Bridges USDC to another chain
   * @param toChainId The id of destination chain
   * @param amount The amount of token
   */
  function bridgeUsdc(uint32 toChainId, uint256 amount) external;

  /**
   * @notice Receives USDC from another chain
   * @param message The id of message
   * @param attestation The attestation of the message
   */
  function receiveUsdc(bytes calldata message, bytes calldata attestation) external;
}
