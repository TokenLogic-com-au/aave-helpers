// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAaveCctpBridge
/// @author TokenLogic
/// @notice Interface for the Aave CCTP V2 Bridge adapter for USDC cross-chain transfers
interface IAaveCctpBridge {
    /// @notice Transfer speed options for CCTP V2
    enum TransferSpeed {
        Fast,    // Finality threshold 1000 - faster but with fee
        Standard // Finality threshold 2000 - slower but potentially lower/no fee
    }

    /// @notice Emitted when a bridge transfer is initiated
    /// @param token The address of the bridged token (USDC)
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param receiver The recipient address on the destination chain
    /// @param amount The amount of tokens bridged
    /// @param nonce The unique nonce assigned to this transfer
    /// @param speed The transfer speed used (Fast or Standard)
    event Bridge(
        address indexed token,
        uint32 indexed destinationDomain,
        address indexed receiver,
        uint256 amount,
        uint64 nonce,
        TransferSpeed speed
    );

    /// @dev Amount provided is zero
    error InvalidZeroAmount();

    /// @dev Destination domain matches local domain
    error InvalidDestinationDomain();

    /// @dev Receiver address is zero address
    error InvalidReceiver();

    /// @dev Constructor parameter is zero address
    error InvalidZeroAddress();

    /// @notice Returns the TokenMessengerV2 contract address
    /// @return Address of the CCTP V2 TokenMessenger
    function TOKEN_MESSENGER() external view returns (address);

    /// @notice Returns the USDC token address on this chain
    /// @return Address of the USDC token
    function USDC() external view returns (address);

    /// @notice Returns the local CCTP domain identifier
    /// @return The domain ID for this chain
    function LOCAL_DOMAIN() external view returns (uint32);

    /// @notice Bridges USDC to a destination chain using CCTP V2
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param amount The amount of USDC to bridge
    /// @param receiver The recipient address on the destination chain
    /// @param maxFee Maximum fee willing to pay for Fast Transfer (in USDC)
    /// @param speed Transfer speed (Fast or Standard)
    /// @return The unique nonce assigned to this transfer
    function bridge(
        uint32 destinationDomain,
        uint256 amount,
        address receiver,
        uint256 maxFee,
        TransferSpeed speed
    ) external returns (uint64);

    /// @notice Bridges USDC with Fast Transfer using default max fee
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param amount The amount of USDC to bridge
    /// @param receiver The recipient address on the destination chain
    /// @return The unique nonce assigned to this transfer
    function bridgeFast(
        uint32 destinationDomain,
        uint256 amount,
        address receiver
    ) external returns (uint64);

    /// @notice Bridges USDC with Standard Transfer (no fee)
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param amount The amount of USDC to bridge
    /// @param receiver The recipient address on the destination chain
    /// @return The unique nonce assigned to this transfer
    function bridgeStandard(
        uint32 destinationDomain,
        uint256 amount,
        address receiver
    ) external returns (uint64);

    /// @notice Quotes the minimum fee for a transfer
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param amount The amount of USDC to bridge
    /// @return The minimum fee required
    function quoteFee(uint32 destinationDomain, uint256 amount) external view returns (uint256);
}
