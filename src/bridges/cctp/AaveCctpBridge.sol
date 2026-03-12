// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICollector} from 'aave-address-book/AaveV3.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {RescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IAaveCctpBridge} from './interfaces/IAaveCctpBridge.sol';
import {IMessageTransmitterV2} from './interfaces/IMessageTransmitterV2.sol';
import {ITokenMessengerV2} from './interfaces/ITokenMessengerV2.sol';

/// @title AaveCctpBridge
/// @author stevyhacker (TokenLogic)
/// @notice Helper contract to bridge USDC using Circle's CCTP V2
contract AaveCctpBridge is OwnableWithGuardian, RescuableBase, IAaveCctpBridge {
  using SafeERC20 for IERC20;

  /// @notice Finality threshold constant for Fast Transfer is 1000 and means just tx confirmation is sufficient
  /// @dev Required confirmations per chain https://developers.circle.com/cctp/required-block-confirmations#cctp-fast-message-attestation-times
  uint32 public constant FAST = 1000;

  /// @notice Finality threshold constant for Standard Transfer is 2000 and means hard finality is requested
  /// @dev Required confirmations per chain https://developers.circle.com/cctp/required-block-confirmations#cctp-standard-message-attestation-times
  uint32 public constant STANDARD = 2000;

  /// @inheritdoc IAaveCctpBridge
  address public immutable TOKEN_MESSENGER;

  /// @inheritdoc IAaveCctpBridge
  address public immutable USDC;

  /// @inheritdoc IAaveCctpBridge
  address public immutable COLLECTOR;

  /// @inheritdoc IAaveCctpBridge
  uint32 public immutable LOCAL_DOMAIN;

  /// @inheritdoc IAaveCctpBridge
  mapping(bytes32 receiver => bool allowed) public isAllowedReceiver;

  /// @param tokenMessenger The TokenMessengerV2 address on this chain
  /// @param usdc The USDC token address on this chain
  /// @param owner The owner of the contract upon deployment
  /// @param guardian The initial guardian of the contract upon deployment
  /// @param collector The address of the source collector on this chain
  constructor(
    address tokenMessenger,
    address usdc,
    address owner,
    address guardian,
    address collector
  ) OwnableWithGuardian(owner, guardian) {
    if (tokenMessenger == address(0)) revert InvalidZeroAddress();
    if (usdc == address(0)) revert InvalidZeroAddress();
    if (guardian == address(0)) revert InvalidZeroAddress();
    if (collector == address(0)) revert InvalidZeroAddress();

    TOKEN_MESSENGER = tokenMessenger;
    USDC = usdc;
    COLLECTOR = collector;

    address localMessageTransmitter = ITokenMessengerV2(tokenMessenger).localMessageTransmitter();
    LOCAL_DOMAIN = IMessageTransmitterV2(localMessageTransmitter).localDomain();
  }

  /// @dev Enables receiving native tokens so they can be rescued back to COLLECTOR if needed
  receive() external payable {}

  /// @inheritdoc IAaveCctpBridge
  function bridge(
    uint32 destinationDomain,
    uint256 amount,
    address receiver,
    uint256 maxFee,
    TransferSpeed speed
  ) external onlyOwnerOrGuardian {
    _bridge(destinationDomain, amount, bytes32(uint256(uint160(receiver))), maxFee, speed);
  }

  /// @inheritdoc IAaveCctpBridge
  function bridgeNonEvm(
    uint32 destinationDomain,
    uint256 amount,
    bytes32 receiver,
    uint256 maxFee,
    TransferSpeed speed
  ) external onlyOwnerOrGuardian {
    _bridge(destinationDomain, amount, receiver, maxFee, speed);
  }

  /// @inheritdoc IAaveCctpBridge
  function setAllowedReceiver(address receiver, bool allowed) external onlyOwner {
    if (receiver == address(0)) revert InvalidZeroAddress();
    isAllowedReceiver[bytes32(uint256(uint160(receiver)))] = allowed;
  }

  /// @inheritdoc IAaveCctpBridge
  function setAllowedReceiverNonEVM(bytes32 receiver, bool allowed) external onlyOwner {
    if (receiver == bytes32(0)) revert InvalidZeroAddress();
    isAllowedReceiver[receiver] = allowed;
  }

  /// @inheritdoc IAaveCctpBridge
  function rescueToken(address token) external onlyOwnerOrGuardian {
    _emergencyTokenTransfer(token, COLLECTOR, type(uint256).max);
  }

  /// @inheritdoc IAaveCctpBridge
  function rescueEth() external onlyOwnerOrGuardian {
    _emergencyEtherTransfer(COLLECTOR, address(this).balance);
  }

  /// @inheritdoc RescuableBase
  function maxRescue(address token) public view override(RescuableBase) returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function _bridge(
    uint32 destinationDomain,
    uint256 amount,
    bytes32 receiver,
    uint256 maxFee,
    TransferSpeed speed
  ) internal {
    if (amount == 0) revert InvalidZeroAmount();
    if (destinationDomain == LOCAL_DOMAIN) revert InvalidDestinationDomain();
    if (!isAllowedReceiver[receiver]) revert OnlyAllowedRecipients();

    uint32 finalityThreshold = speed == TransferSpeed.Fast ? FAST : STANDARD;

    ICollector(COLLECTOR).transfer(IERC20(USDC), address(this), amount);
    IERC20(USDC).forceApprove(TOKEN_MESSENGER, amount);

    ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
      amount,
      destinationDomain,
      receiver,
      USDC,
      bytes32(0),
      maxFee,
      finalityThreshold
    );

    emit Bridge(USDC, destinationDomain, receiver, amount, speed);
  }
}
