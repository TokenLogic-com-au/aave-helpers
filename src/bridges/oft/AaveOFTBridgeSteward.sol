// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ICollector} from 'aave-v3-origin/contracts/treasury/ICollector.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IAaveOFTBridgeSteward} from './interfaces/IAaveOFTBridgeSteward.sol';
import {IOFT, SendParam, MessagingFee, OFTReceipt} from './interfaces/IOFT.sol';

/// @title AaveOFTBridge
/// @author @stevyhacker (TokenLogic)
/// @notice Helper contract to bridge USDT using OFT V2 (LayerZero OFT)
contract AaveOFTBridgeSteward is OwnableWithGuardian, RescuableBase, IAaveOFTBridgeSteward {
  using SafeERC20 for IERC20;

  /// @inheritdoc IAaveOFTBridgeSteward
  address public immutable OFT_USDT;

  /// @inheritdoc IAaveOFTBridgeSteward
  address public immutable USDT;

  /// @inheritdoc IAaveOFTBridgeSteward
  address public immutable COLLECTOR;

  mapping(address receiver => bool allowed) public isAllowedReciever;

  /// @param oftUsdt The OFT address for USDT on this chain
  /// @param initialOwner The initial owner of the contract
  /// @param initialGuardian The initial guardian of the contract
  /// @param collector The address to collect fees
  constructor(
    address oftUsdt,
    address initialOwner,
    address initialGuardian,
    address collector
  ) OwnableWithGuardian(initialOwner, initialGuardian) {
    if (initialGuardian == address(0)) revert InvalidZeroAddress();
    if (collector == address(0)) revert InvalidZeroAddress();
    if (oftUsdt == address(0)) revert InvalidZeroAddress();

    COLLECTOR = collector;
    OFT_USDT = oftUsdt;
    USDT = IOFT(OFT_USDT).token();
  }

  /// @dev Default receive function enabling the contract to accept native tokens for gas fees
  receive() external payable {}

  /// @inheritdoc IAaveOFTBridgeSteward
  function bridge(
    uint32 dstEid,
    uint256 amount,
    address receiver,
    uint256 minAmountLD,
    uint256 maxFee
  ) external payable onlyOwnerOrGuardian {
    require(amount > 0, InvalidZeroAmount());
    require(isAllowedReciever[receiver], OnlyAllowedRecipients());

    ICollector(COLLECTOR).transfer(IERC20(USDT), address(this), amount);

    SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, minAmountLD);

    MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);

    require(messagingFee.nativeFee <= maxFee, ExceedsMaxFee());

    IERC20(USDT).forceApprove(OFT_USDT, amount);

    IOFT(OFT_USDT).send{value: messagingFee.nativeFee}(sendParam, messagingFee, COLLECTOR);

    emit Bridge(USDT, dstEid, receiver, amount, minAmountLD);
  }

  /// @inheritdoc IAaveOFTBridgeSteward
  function setAllowedReceiver(address receiver, bool allowed) external onlyOwner {
    require(receiver != address(0), InvalidZeroAddress());
    isAllowedReciever[receiver] = allowed;
  }

  /// @inheritdoc IAaveOFTBridgeSteward
  function rescueToken(address token) external onlyOwnerOrGuardian {
    _emergencyTokenTransfer(token, COLLECTOR, type(uint256).max);
  }

  /// @inheritdoc IAaveOFTBridgeSteward
  function rescueEth() external onlyOwnerOrGuardian {
    _emergencyEtherTransfer(COLLECTOR, address(this).balance);
  }

  /// @inheritdoc IAaveOFTBridgeSteward
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

  /// @inheritdoc IAaveOFTBridgeSteward
  function quoteOFT(
    uint32 dstEid,
    uint256 amount,
    address receiver
  ) external view returns (uint256) {
    SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, 0);
    (, , OFTReceipt memory receipt) = IOFT(OFT_USDT).quoteOFT(sendParam);
    return receipt.amountReceivedLD;
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(address token) public view override(RescuableBase) returns (uint256) {
    return IERC20(token).balanceOf(address(this));
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
