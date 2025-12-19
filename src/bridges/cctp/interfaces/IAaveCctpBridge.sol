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

    /// @notice Emitted when a collector address is set for a destination domain
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param collector The collector address for that domain (bytes32 to support non-EVM)
    event CollectorSet(uint32 indexed destinationDomain, bytes32 indexed collector);

    /// @dev Amount provided is zero
    error InvalidZeroAmount();

    /// @dev Destination domain matches local domain
    error InvalidDestinationDomain();

    /// @dev Constructor parameter is zero address
    error InvalidZeroAddress();

    /// @dev No collector configured for the destination domain
    error CollectorNotConfigured(uint32 destinationDomain);

    /// @notice Bridges USDC to a destination chain using CCTP V2
    /// @dev Receiver is the pre-configured collector for the destination domain
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param amount The amount of USDC to bridge
    /// @param maxFee Maximum fee willing to pay for Fast Transfer (in USDC)
    /// @param speed Transfer speed (Fast or Standard)
    function bridge(
        uint32 destinationDomain,
        uint256 amount,
        uint256 maxFee,
        TransferSpeed speed
    ) external;

    /// @notice Returns the TokenMessengerV2 contract address
    /// @return Address of the CCTP V2 TokenMessenger
    function TOKEN_MESSENGER() external view returns (address);

    /// @notice Returns the USDC token address on this chain
    /// @return Address of the USDC token
    function USDC() external view returns (address);

    /// @notice Returns the local CCTP domain identifier
    /// @return The domain ID for this chain
    function LOCAL_DOMAIN() external view returns (uint32);

    /// @notice Sets the collector address for a destination domain
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @param collector The collector address for that domain (bytes32 to support non-EVM)
    function setDestinationCollector(uint32 destinationDomain, bytes32 collector) external;

    /// @notice Returns the collector address for a destination domain
    /// @param destinationDomain The CCTP domain of the destination chain
    /// @return The collector address for that domain
    function getDestinationCollector(uint32 destinationDomain) external view returns (bytes32);
}
