// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IAaveOFTBridge} from './interfaces/IAaveOFTBridge.sol';
import {IOFT, SendParam, MessagingFee, OFTReceipt} from './interfaces/IOFT.sol';

/// @title AaveOFTBridge
/// @author @stevyhacker (TokenLogic)
/// @notice Helper contract to bridge USDT using OFT V2 (LayerZero OFT)
contract AaveOFTBridge is OwnableWithGuardian, Rescuable, IAaveOFTBridge {
  using SafeERC20 for IERC20;

  /// @inheritdoc IAaveOFTBridge
  address public immutable OFT_USDT;

  /// @inheritdoc IAaveOFTBridge
  address public immutable USDT;

  /// @param oftUsdt The OFT address for USDT on this chain
  /// @param owner The owner of the contract upon deployment
  constructor(address oftUsdt, address owner, address guardian) OwnableWithGuardian(owner, guardian) {
    require(oftUsdt != address(0), InvalidZeroAddress());
    OFT_USDT = oftUsdt;
    USDT = IOFT(OFT_USDT).token();
  }

  /// @dev Default receive function enabling the contract to accept native tokens for gas fees
  receive() external payable {}

  /// @inheritdoc IAaveOFTBridge
  function bridge(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD
  ) external payable onlyOwnerOrGuardian {
    require(amount >= 1, InvalidZeroAmount());

    IERC20(USDT).safeTransferFrom(msg.sender, address(this), amount);

    SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, minAmountLD);

    MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);

    IERC20(USDT).forceApprove(OFT_USDT, amount);

    IOFT(OFT_USDT).send{value: messagingFee.nativeFee}(sendParam, messagingFee, msg.sender);

    emit Bridge(USDT, dstEid, receiver, amount, minAmountLD);
  }

  /// @inheritdoc IAaveOFTBridge
  function quoteBridge(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD
  ) external view returns (uint256) {
    SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, minAmountLD);
    MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);
    return messagingFee.nativeFee;
  }

  /// @inheritdoc IAaveOFTBridge
  function quoteOFT(
    uint32 dstEid,
    uint256 amount,
    address receiver
  ) external view returns (uint256) {
    SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, 0);
    (, , OFTReceipt memory receipt) = IOFT(OFT_USDT).quoteOFT(sendParam);
    return receipt.amountReceivedLD;
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return owner();
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(
    address
  ) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
    return type(uint256).max;
  }

  /// @dev Builds the SendParam struct for OFT transfer
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param amount The amount to send
  /// @param receiver The receiver address on destination
  /// @param minAmountLD The minimum amount to receive
  /// @return The constructed SendParam struct
  function _buildSendParam(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD
  ) internal pure returns (SendParam memory) {
    return
      SendParam({
        dstEid: dstEid,
        to: bytes32(uint256(uint160(receiver))),
        amountLD: amount,
        minAmountLD: minAmountLD,
        extraOptions: new bytes(0),
        composeMsg: new bytes(0),
        oftCmd: new bytes(0)
      });
  }
}
