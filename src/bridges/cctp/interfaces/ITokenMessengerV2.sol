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
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}
