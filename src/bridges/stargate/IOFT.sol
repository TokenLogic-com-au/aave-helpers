// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

interface IOFT {
    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);

    function quoteOFT(SendParam calldata _sendParam)
        external
        view
        returns (uint256 amountSentLD, uint256 amountReceivedLD, OFTReceipt memory receipt);

    function token() external view returns (address);
}
