// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {LinkTokenInterface} from '@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol';
import {CCIPReceiver} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';

import {IAaveCcipGhoBridge} from './IAaveCcipGhoBridge.sol';

/**
 * @title AaveCcipGhoBridge
 * @author LucasWongC
 * @notice Helper contract to bridge GHO using Chainlink CCIP
 */
contract AaveCcipGhoBridge is IAaveCcipGhoBridge, CCIPReceiver, OwnableWithGuardian {
  /// @dev Chainlink CCIP router address
  address public immutable ROUTER;
  /// @dev LINK token address
  address public immutable LINK;
  /// @dev GHO token address
  address public immutable GHO;

  /// @dev Address of bridge (chainSelector => bridge address)
  mapping(uint64 selector => address bridge) public bridges;

  /**
   * @param _router The address of the Chainlink CCIP router
   * @param _link The address of the LINK token
   * @param _gho The address of the GHO token
   * @param _owner The address of the contract owner
   * @param _guardian The address of guardian
   */
  constructor(
    address _router,
    address _link,
    address _gho,
    address _owner,
    address _guardian
  ) CCIPReceiver(_router) {
    ROUTER = _router;
    LINK = _link;
    GHO = _gho;

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
  }

  receive() external payable {}

  /// @dev Checks if the destination bridge has been set up
  modifier checkDestination(uint64 chainSelector) {
    if (bridges[chainSelector] == address(0)) {
      revert UnsupportedChain();
    }
    _;
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function transfer(
    uint64 destinationChainSelector,
    Transfer[] calldata transfers,
    PayFeesIn payFeesIn
  )
    external
    payable
    checkDestination(destinationChainSelector)
    onlyOwnerOrGuardian
    returns (bytes32 messageId)
  {
    uint256 totalAmount;

    uint256 length = transfers.length;
    for (uint256 i; i < length; ) {
      totalAmount += transfers[i].amount;

      unchecked {
        ++i;
      }
    }

    if (totalAmount == 0) {
      revert InvalidTransferAmount();
    }

    IERC20(GHO).transferFrom(msg.sender, address(this), totalAmount);
    IERC20(GHO).approve(ROUTER, totalAmount);

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: totalAmount});

    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(bridges[destinationChainSelector]),
      data: abi.encode(transfers),
      tokenAmounts: tokenAmounts,
      extraArgs: '',
      feeToken: payFeesIn == PayFeesIn.LINK ? LINK : address(0)
    });

    uint256 fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);

    if (payFeesIn == PayFeesIn.LINK) {
      LinkTokenInterface(LINK).transferFrom(msg.sender, address(this), fee);
      LinkTokenInterface(LINK).approve(ROUTER, fee);
      messageId = IRouterClient(ROUTER).ccipSend(destinationChainSelector, message);
    } else {
      if (msg.value < fee) {
        revert InsufficientFee();
      }

      messageId = IRouterClient(ROUTER).ccipSend{value: fee}(destinationChainSelector, message);
      if (msg.value > fee) {
        payable(msg.sender).transfer(msg.value - fee);
      }
    }

    emit TransferIssued(messageId, destinationChainSelector, totalAmount);
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function quoteTransfer(
    uint64 destinationChainSelector,
    Transfer[] calldata transfers,
    PayFeesIn payFeesIn
  ) external view checkDestination(destinationChainSelector) returns (uint256 fee) {
    uint256 totalAmount;

    uint256 length = transfers.length;
    for (uint256 i; i < length; ) {
      totalAmount += transfers[i].amount;

      unchecked {
        ++i;
      }
    }

    if (totalAmount == 0) {
      revert InvalidTransferAmount();
    }

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: totalAmount});

    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(bridges[destinationChainSelector]),
      data: abi.encode(transfers),
      tokenAmounts: tokenAmounts,
      extraArgs: '',
      feeToken: payFeesIn == PayFeesIn.LINK ? LINK : address(0)
    });

    fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);
  }

  /// @inheritdoc CCIPReceiver
  function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
    bytes32 messageId = message.messageId;
    uint64 sourceChainSelector = message.sourceChainSelector;
    address bridge = abi.decode(message.sender, (address));
    Transfer[] memory transfers = abi.decode(message.data, (Transfer[]));

    if (bridge != bridges[sourceChainSelector]) {
      revert InvalidMessage();
    }

    uint256 length = transfers.length;
    for (uint256 i; i < length; ) {
      IERC20(GHO).transfer(transfers[i].to, transfers[i].amount);

      unchecked {
        ++i;
      }
    }

    emit TransferFinished(messageId);
  }

  /**
   * @notice Set up destination bridge data
   * @param _destinationChainSelector The selector of the destination chain
   * @param _bridge The address of the bridge
   */
  function setDestinationBridge(
    uint64 _destinationChainSelector,
    address _bridge
  ) external onlyOwner {
    bridges[_destinationChainSelector] = _bridge;

    emit DestinationUpdated(_destinationChainSelector, _bridge);
  }
}
