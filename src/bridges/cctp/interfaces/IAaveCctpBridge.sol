// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAaveCctpBridge
/// @author TokenLogic
/// @notice Interface for the Aave CCTP V2 Bridge adapter for USDC cross-chain transfers
interface IAaveCctpBridge {
  /// @notice Transfer speed options for CCTP V2
  enum TransferSpeed {
    Fast, // Finality threshold 1000 - faster but with fee
    Standard // Finality threshold 2000 - slower but potentially lower/no fee
  }

  /// @notice Emitted when a bridge transfer is initiated
  /// @param token The address of the bridged token (USDC)
  /// @param destinationDomain The CCTP domain of the destination chain
  /// @param receiver The recipient address on the destination chain (bytes32 to support non-EVM)
  /// @param amount The amount of tokens bridged
  /// @param speed The transfer speed used (Fast or Standard)
  event Bridge(
    address indexed token,
    uint32 indexed destinationDomain,
    bytes32 indexed receiver,
    uint256 amount,
    TransferSpeed speed
  );

  /// @dev Amount provided is zero
  error InvalidZeroAmount();

  /// @dev Destination domain matches local domain
  error InvalidDestinationDomain();

  /// @dev Constructor parameter is zero address
  error InvalidZeroAddress();

  /// @dev Receiver is not allowlisted
  error OnlyAllowedRecipients();

  /// @notice Bridges USDC to a destination chain using CCTP V2
  /// @param destinationDomain The CCTP domain of the destination chain
  /// @param amount The amount of USDC to bridge, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param receiver The EVM receiver address on destination chain
  /// @param maxFee Maximum fee willing to pay for a Fast Transfer, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param speed Transfer speed (Fast or Standard)
  function bridge(
    uint32 destinationDomain,
    uint256 amount,
    address receiver,
    uint256 maxFee,
    TransferSpeed speed
  ) external;

  /// @notice Bridges USDC to a destination chain using CCTP V2 with a non-EVM receiver identifier
  /// @param destinationDomain The CCTP domain of the destination chain
  /// @param amount The amount of USDC to bridge, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param receiver The non-EVM receiver identifier
  /// @param maxFee Maximum fee willing to pay for a Fast Transfer, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param speed Transfer speed (Fast or Standard)
  function bridgeNonEvm(
    uint32 destinationDomain,
    uint256 amount,
    bytes32 receiver,
    uint256 maxFee,
    TransferSpeed speed
  ) external;

  /// @notice Sets whether a receiver is allowed for bridge execution
  /// @param receiver The destination receiver address
  /// @param allowed Whether the receiver is allowed
  function setAllowedReceiver(address receiver, bool allowed) external;

  /// @notice Sets whether a non-EVM receiver is allowed for bridge execution
  /// @param receiver The destination receiver identifier
  /// @param allowed Whether the receiver is allowed
  function setAllowedReceiverNonEVM(bytes32 receiver, bool allowed) external;

  /// @notice Rescues an ERC20 token balance to the source collector
  /// @param token The token address to rescue
  function rescueToken(address token) external;

  /// @notice Rescues native token balance to the source collector
  function rescueEth() external;

  /// @notice Returns the TokenMessengerV2 contract address
  /// @return Address of the CCTP V2 TokenMessenger
  function TOKEN_MESSENGER() external view returns (address);

  /// @notice Returns the USDC token address on this chain
  /// @return Address of the USDC token
  function USDC() external view returns (address);

  /// @notice Returns the source collector address on this chain
  /// @return Address of the source collector
  function COLLECTOR() external view returns (address);

  /// @notice Returns the local CCTP domain identifier
  /// @return The domain ID for this chain
  function LOCAL_DOMAIN() external view returns (uint32);

  /// @notice Returns whether a receiver is allowed for bridge execution
  /// @param receiver The destination receiver identifier
  /// @return Whether the receiver is allowed
  function isAllowedReceiver(bytes32 receiver) external view returns (bool);
}
