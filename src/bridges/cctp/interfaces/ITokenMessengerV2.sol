// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ITokenMessengerV2
/// @notice Interface for Circle's CCTP V2 TokenMessenger contract
/// @dev https://developers.circle.com/cctp/evm-smart-contracts#tokenmessengerv2
interface ITokenMessengerV2 {
    /// @notice Deposits and burns tokens from sender to be minted on destination domain
    /// @param amount Amount of tokens to deposit and burn
    /// @param destinationDomain Destination domain identifier
    /// @param mintRecipient Address of mint recipient on destination domain (as bytes32)
    /// @param burnToken Address of contract to burn deposited tokens
    /// @param destinationCaller Address that can call receiveMessage on destination (bytes32(0) for any)
    /// @param maxFee Maximum fee for Fast Transfer (in burn token units)
    /// @param minFinalityThreshold Minimum finality level (1000 for Fast, 2000 for Standard)
    /// @return Unique nonce reserved by message
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external returns (uint64);

    /// @notice Calculates the minimum fee for Standard Transfer
    /// @param destinationDomain Destination domain identifier
    /// @param burnToken Address of the burn token
    /// @param amount Amount of tokens to transfer
    /// @return The minimum fee amount
    function getMinFeeAmount(
        uint32 destinationDomain,
        address burnToken,
        uint256 amount
    ) external view returns (uint256);

    /// @notice Returns the local MessageTransmitterV2 contract address
    /// @return Address of the MessageTransmitterV2
    function localMessageTransmitter() external view returns (address);
}
