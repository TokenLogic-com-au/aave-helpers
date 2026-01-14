// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt, OFTLimit, OFTFeeDetail} from '../../../../src/bridges/oft/interfaces/IOFT.sol';

contract MockOFT is IOFT {
  using SafeERC20 for IERC20;

  address public immutable override token;
  uint256 public mockNativeFee;
  uint256 public mockLzTokenFee;
  uint256 public mockAmountReceivedLD;

  event SendTokenCalled(
    uint32 dstEid,
    bytes32 to,
    uint256 amountLD,
    uint256 minAmountLD,
    address refundAddress
  );

  constructor(address _token) {
    token = _token;
    mockNativeFee = 0.01 ether;
    mockLzTokenFee = 0;
  }

  function setMockFee(uint256 _nativeFee, uint256 _lzTokenFee) external {
    mockNativeFee = _nativeFee;
    mockLzTokenFee = _lzTokenFee;
  }

  function setMockAmountReceived(uint256 _amountReceivedLD) external {
    mockAmountReceivedLD = _amountReceivedLD;
  }

  function send(
    SendParam calldata _sendParam,
    MessagingFee calldata,
    address _refundAddress
  )
    external
    payable
    override
    returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
  {
    IERC20(token).safeTransferFrom(msg.sender, address(this), _sendParam.amountLD);

    emit SendTokenCalled(
      _sendParam.dstEid,
      _sendParam.to,
      _sendParam.amountLD,
      _sendParam.minAmountLD,
      _refundAddress
    );

    msgReceipt = MessagingReceipt({
      guid: keccak256(abi.encode(_sendParam)),
      nonce: 1,
      fee: MessagingFee({nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee})
    });

    oftReceipt = OFTReceipt({
      amountSentLD: _sendParam.amountLD,
      amountReceivedLD: mockAmountReceivedLD > 0 ? mockAmountReceivedLD : _sendParam.amountLD
    });
  }

  function quoteSend(
    SendParam calldata,
    bool
  ) external view override returns (MessagingFee memory) {
    return MessagingFee({nativeFee: mockNativeFee, lzTokenFee: mockLzTokenFee});
  }

  function quoteOFT(
    SendParam calldata _sendParam
  )
    external
    view
    override
    returns (OFTLimit memory limit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory receipt)
  {
    uint256 amountSentLD = _sendParam.amountLD;
    uint256 amountReceivedLD = mockAmountReceivedLD > 0
      ? mockAmountReceivedLD
      : _sendParam.amountLD;
    limit = OFTLimit({minAmountLD: 0, maxAmountLD: type(uint256).max});
    oftFeeDetails = new OFTFeeDetail[](0);
    receipt = OFTReceipt({amountSentLD: amountSentLD, amountReceivedLD: amountReceivedLD});
  }

  function oftVersion() external pure override returns (bytes4 interfaceId, uint64 version) {
    return (0x02e49c2c, 1);
  }

  function approvalRequired() external pure override returns (bool) {
    return true;
  }

  function sharedDecimals() external pure override returns (uint8) {
    return 6;
  }
}
