// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveOFTBridgeSteward {
  /// @dev Thrown when bridge amount is zero
  error InvalidZeroAmount();

  /// @dev Thrown when a zero address is provided
  error InvalidZeroAddress();

  /// @dev Thrown when the max fee is exceeded
  error ExceedsMaxFee();

  /// @dev Thrown when a recipient is passed which is not allowed in the mapping
  error OnlyAllowedRecipients();

  /// @notice Emitted when USDT is bridged to a destination chain
  /// @param token The token address being bridged
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param receiver The receiver address on destination
  /// @param amount The amount bridged
  /// @param minAmountReceived The minimum expected amount on destination
  event Bridge(
    address indexed token,
    uint32 indexed dstEid,
    address indexed receiver,
    uint256 amount,
    uint256 minAmountReceived
  );

  /// @notice Bridges USDT to a destination chain using OFT
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param amount The amount of USDT to bridge
  /// @param receiver The receiver address on the destination chain
  /// @param minAmountLD The minimum amount to receive on destination (slippage protection)
  /// @param maxFee The maximum native fee in ETH wei allowed for the bridge
  function bridge(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD,
    uint256 maxFee
  ) external payable;

  /// @notice Updates whitelist for allowed receivers to receive bridged tokens
  /// @param receiver The receiver address
  /// @param allowed Whether the receiver is allowed
  function setAllowedReceiver(address receiver, bool allowed) external;

  /// @notice Rescues the specified token back to the Collector
  /// @param token The address of the ERC20 token to rescue
  function rescueToken(address token) external;

  /// @notice Rescues ETH from the contract back to the Collector
  function rescueEth() external;

  /// @notice Returns the OFT address for USDT on the deployed chain
  function OFT_USDT() external view returns (address);

  /// @notice Returns the USDT token address on the deployed chain
  function USDT() external view returns (address);

  /// @notice Returns the Aave Collector address
  function COLLECTOR() external view returns (address);

  /// @notice Quotes the native fee required to bridge USDT
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param amount The amount of USDT to bridge
  /// @param receiver The receiver address on the destination chain
  /// @param minAmountLD The minimum amount to receive on destination
  /// @return nativeFee The native token fee required for bridging
  function quoteBridge(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD
  ) external view returns (uint256);

  /// @notice Quotes the OFT to get the expected amount received on destination
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param amount The amount of USDT to bridge
  /// @param receiver The receiver address on the destination chain
  /// @return amountReceivedLD The expected amount to receive on destination
  function quoteOFT(
    uint32 dstEid,
    uint256 amount,
    address receiver
  ) external view returns (uint256);
}
