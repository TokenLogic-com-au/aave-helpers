// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveStargateBridge {
    /// @dev Thrown when bridge amount is zero
    error InvalidZeroAmount();

    /// @dev Thrown when a zero address is provided
    error InvalidZeroAddress();

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

    /// @notice Bridges USDT to a destination chain using Stargate
    /// @param dstEid The destination LayerZero endpoint ID
    /// @param amount The amount of USDT to bridge
    /// @param receiver The receiver address on the destination chain
    /// @param minAmountLD The minimum amount to receive on destination (slippage protection)
    function bridge(uint32 dstEid, uint256 amount, address receiver, uint256 minAmountLD) external payable;

    /// @notice Returns the Stargate OFT address for USDT on the deployed chain
    function OFT_USDT() external view returns (address);

    /// @notice Returns the USDT token address on the deployed chain
    function USDT() external view returns (address);

    /// @notice Quotes the native fee required to bridge USDT
    /// @param dstEid The destination LayerZero endpoint ID
    /// @param amount The amount of USDT to bridge
    /// @param receiver The receiver address on the destination chain
    /// @param minAmountLD The minimum amount to receive on destination
    /// @return nativeFee The native token fee required for bridging
    function quoteBridge(uint32 dstEid, uint256 amount, address receiver, uint256 minAmountLD)
        external
        view
        returns (uint256);

    /// @notice Quotes the OFT to get the expected amount received on destination
    /// @param dstEid The destination LayerZero endpoint ID
    /// @param amount The amount of USDT to bridge
    /// @param receiver The receiver address on the destination chain
    /// @return amountReceivedLD The expected amount to receive on destination
    function quoteOFT(uint32 dstEid, uint256 amount, address receiver) external view returns (uint256);
}
