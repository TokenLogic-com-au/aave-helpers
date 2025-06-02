// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveGhoCcipBridge {
    ///        chain selector can be found https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet
    error InsufficientFee();
    error InvalidZeroAddress();
    error InvalidZeroAmount();

    /// @dev Returns this error when message not found
    error MessageNotFound();

    /// @dev The bridge's rate limit has been exceeded
    error RateLimitExceeded(uint256 limit);

    error UnknownSourceDestination();

    /**
     * @dev Emits when the destination bridge data is updated
     * @param chainSelector The selector of the destination chain
     * @param bridge The address of the bridge on the destination chain
     */
    event DestinationBridgeSet(uint64 indexed chainSelector, address indexed bridge);

    /**
     * @dev Emitted when an invalid message is received by the bridge
     * @param messageId The ID of message
     */
    event InvalidMessageReceived(bytes32 indexed messageId);

    /**
     * @dev Emitted when a new GHO transfer is issued
     * @param messageId The ID of the cross-chain message
     * @param destinationChainSelector The selector of the destination chain
     * @param from The address of sender on source chain
     * @param amount The total amount of GHO transfered
     */
    event BridgeInitiated(
        bytes32 indexed messageId, uint64 indexed destinationChainSelector, address indexed from, uint256 amount
    );

    /**
     * @dev Emits when the token transfer is executed on the destination chain
     * @param messageId The ID of the cross-chain message
     * @param to The address of receiver on destination chain
     * @param amount The amount of token to translated
     */
    event BridgeFinalized(bytes32 indexed messageId, address indexed to, uint256 amount);
}
