// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAaveCctpBridge} from './IAaveCctpBridge.sol';
import {ICctpMessageTransmitter} from './ICctpMessageTransmitter.sol';
import {ICctpTokenMessenger} from './ICctpTokenMessenger.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';

/**
 * @title AaveCctpBridge
 * @notice Bridges USDC between evm chains
 * @author LucasWongC
 */
contract AaveCctpBridge is IAaveCctpBridge, OwnableWithGuardian, Rescuable {
  /// @dev The messenger address of cctp protocol
  address public immutable TOKEN_MESSENGER;
  /// @dev The message transmitter address of cctp protocol
  address public immutable MESSAGE_TRANSMITTER;
  /// @dev The address of usdc
  IERC20 public immutable USDC;

  /// @dev The addres of collector on another chain
  mapping(uint32 chainId => address collector) public collectors;

  /**
   * @param _tokenMessenger The address of token messenger
   * @param _messageTransmitter The address of message transmitter
   * @param _usdc The address of usdc
   * @param _owner The address of owner
   * @param _guardian The address of guardian
   */
  constructor(
    address _tokenMessenger,
    address _messageTransmitter,
    address _usdc,
    address _owner,
    address _guardian
  ) {
    TOKEN_MESSENGER = _tokenMessenger;
    MESSAGE_TRANSMITTER = _messageTransmitter;
    USDC = IERC20(_usdc);

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
  }

  /// @inheritdoc IAaveCctpBridge
  function bridgeUsdc(uint32 _toChainId, uint256 _amount) external onlyOwnerOrGuardian {
    if (collectors[_toChainId] == address(0)) {
      revert InvalidChain();
    }

    if (_amount == 0) {
      revert ZeroAmount();
    }

    USDC.transferFrom(msg.sender, address(this), _amount);
    if (USDC.allowance(address(this), address(TOKEN_MESSENGER)) < type(uint256).max) {
      USDC.approve(address(TOKEN_MESSENGER), type(uint256).max);
    }

    ICctpTokenMessenger(TOKEN_MESSENGER).depositForBurn(
      _amount,
      _toChainId,
      bytes32(uint256(uint160(collectors[_toChainId]))),
      address(USDC)
    );

    emit BridgeMessageSent(_toChainId, _amount);
  }

  /// @inheritdoc IAaveCctpBridge
  function receiveUsdc(bytes calldata _message, bytes calldata _attestation) external {
    ICctpMessageTransmitter(MESSAGE_TRANSMITTER).receiveMessage(_message, _attestation);

    emit BridgeMessageReceived(_message);
  }

  /**
   * @notice Sets collector on destination chain
   * @param _toChainId The id of destination chain
   * @param _collector The address of collector on destination chain
   */
  function setCollector(uint32 _toChainId, address _collector) external onlyOwner {
    collectors[_toChainId] = _collector;

    emit CollectorUpdated(_toChainId, _collector);
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return owner();
  }
}
