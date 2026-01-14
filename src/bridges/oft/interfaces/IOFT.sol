// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Struct representing the fee for LayerZero messaging
struct MessagingFee {
  uint256 nativeFee;
  uint256 lzTokenFee;
}

/// @dev Struct representing the receipt from LayerZero messaging
struct MessagingReceipt {
  bytes32 guid;
  uint64 nonce;
  MessagingFee fee;
}

/// @dev Struct representing token parameters for the OFT send() operation
struct SendParam {
  uint32 dstEid;
  bytes32 to;
  uint256 amountLD;
  uint256 minAmountLD;
  bytes extraOptions;
  bytes composeMsg;
  bytes oftCmd;
}

/// @dev Struct representing OFT limit information
struct OFTLimit {
  uint256 minAmountLD;
  uint256 maxAmountLD;
}

/// @dev Struct representing OFT receipt information
struct OFTReceipt {
  uint256 amountSentLD;
  uint256 amountReceivedLD;
}

/// @dev Struct representing OFT fee details
struct OFTFeeDetail {
  int256 feeAmountLD;
  string description;
}

/// @title IOFT
/// @dev Interface for the OFT (Omnichain Fungible Token) standard
/// @dev This specific interface ID is '0x02e49c2c'
interface IOFT {
  error InvalidLocalDecimals();
  error SlippageExceeded(uint256 amountLD, uint256 minAmountLD);

  event OFTSent(
    bytes32 indexed guid,
    uint32 dstEid,
    address indexed fromAddress,
    uint256 amountSentLD,
    uint256 amountReceivedLD
  );

  event OFTReceived(
    bytes32 indexed guid,
    uint32 srcEid,
    address indexed toAddress,
    uint256 amountReceivedLD
  );

  /// @notice Retrieves interfaceID and the version of the OFT
  function oftVersion() external view returns (bytes4 interfaceId, uint64 version);

  /// @notice Retrieves the address of the token associated with the OFT
  function token() external view returns (address);

  /// @notice Indicates whether the OFT contract requires approval of the 'token()' to send
  function approvalRequired() external view returns (bool);

  /// @notice Retrieves the shared decimals of the OFT
  function sharedDecimals() external view returns (uint8);

  /// @notice Provides a quote for OFT-related operations
  function quoteOFT(
    SendParam calldata _sendParam
  ) external view returns (OFTLimit memory, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory);

  /// @notice Provides a quote for the send() operation
  function quoteSend(
    SendParam calldata _sendParam,
    bool _payInLzToken
  ) external view returns (MessagingFee memory);

  /// @notice Executes the send() operation
  function send(
    SendParam calldata _sendParam,
    MessagingFee calldata _fee,
    address _refundAddress
  ) external payable returns (MessagingReceipt memory, OFTReceipt memory);
}
