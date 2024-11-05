// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {CCIPReceiver} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {IRouter} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouter.sol';
import {EVM2EVMOnRamp} from '@chainlink/contracts-ccip/src/v0.8/ccip/onRamp/EVM2EVMOnRamp.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';

import {IAaveCcipGhoBridge} from './IAaveCcipGhoBridge.sol';

/**
 * @title AaveCcipGhoBridge
 * @author LucasWongC
 * @notice Helper contract to bridge GHO using Chainlink CCIP
 * @dev Sends GHO to AAVE collector of destination chain using chainlink CCIP
 */
contract AaveCcipGhoBridge is IAaveCcipGhoBridge, CCIPReceiver, OwnableWithGuardian, Rescuable {
  using SafeERC20 for IERC20;

  /// @dev Chainlink CCIP router address
  address public immutable ROUTER;
  /// @dev LINK token address
  address public immutable LINK;
  /// @dev GHO token address
  address public immutable GHO;
  /// @dev Aave Collector address
  address public immutable COLLECTOR;

  /// @dev Address of bridge (chainSelector => bridge address)
  mapping(uint64 selector => address bridge) public bridges;

  /// @dev Checks if the destination bridge has been set up
  modifier checkDestination(uint64 chainSelector) {
    if (bridges[chainSelector] == address(0)) {
      revert UnsupportedChain();
    }
    _;
  }

  /// @dev Check fee token is valid on destination chain
  modifier checkFeeToken(uint64 chainSelector, address feeToken) {
    if (feeToken != address(0)) {
      EVM2EVMOnRamp.FeeTokenConfig memory feeTokenConfig = EVM2EVMOnRamp(
        IRouter(ROUTER).getOnRamp(chainSelector)
      ).getFeeTokenConfig(feeToken);
      if (!feeTokenConfig.enabled) revert NotAFeeToken(feeToken);
    }
    _;
  }

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
    address _collector,
    address _owner,
    address _guardian
  ) CCIPReceiver(_router) {
    ROUTER = _router;
    LINK = _link;
    GHO = _gho;
    COLLECTOR = _collector;

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
  }

  receive() external payable {}

  /// @inheritdoc IAaveCcipGhoBridge
  function transfer(
    uint64 destinationChainSelector,
    uint256 amount,
    address feeToken
  )
    external
    payable
    checkDestination(destinationChainSelector)
    onlyOwner
    checkFeeToken(destinationChainSelector, feeToken)
    returns (bytes32 messageId)
  {
    if (amount == 0) {
      revert InvalidTransferAmount();
    }

    IERC20(GHO).transferFrom(msg.sender, address(this), amount);
    IERC20(GHO).approve(ROUTER, amount);

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: amount});

    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(bridges[destinationChainSelector]),
      data: abi.encode(msg.sender),
      tokenAmounts: tokenAmounts,
      extraArgs: '',
      feeToken: feeToken
    });

    uint256 fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);

    if (feeToken != address(0)) {
      if (feeToken == GHO) {
        if (IERC20(feeToken).balanceOf(address(this)) < amount + fee) {
          revert InsufficientFee();
        }
      } else {
        if (IERC20(feeToken).balanceOf(address(this)) < fee) {
          revert InsufficientFee();
        }
      }

      IERC20(feeToken).safeIncreaseAllowance(ROUTER, fee);
      messageId = IRouterClient(ROUTER).ccipSend(destinationChainSelector, message);
    } else {
      if (address(this).balance < fee) {
        revert InsufficientFee();
      }

      messageId = IRouterClient(ROUTER).ccipSend{value: fee}(destinationChainSelector, message);
    }

    emit TransferIssued(messageId, destinationChainSelector, amount);
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function quoteTransfer(
    uint64 destinationChainSelector,
    uint256 amount,
    address feeToken
  )
    external
    view
    checkDestination(destinationChainSelector)
    checkFeeToken(destinationChainSelector, feeToken)
    returns (uint256 fee)
  {
    if (amount == 0) {
      revert InvalidTransferAmount();
    }

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: amount});

    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(bridges[destinationChainSelector]),
      data: abi.encode(msg.sender),
      tokenAmounts: tokenAmounts,
      extraArgs: '',
      feeToken: feeToken
    });

    fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);
  }

  /// @inheritdoc CCIPReceiver
  /// @dev Sends gho to AAVE collector
  function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
    bytes32 messageId = message.messageId;
    Client.EVMTokenAmount[] memory tokenAmounts = message.destTokenAmounts;

    address sender = abi.decode(message.data, (address));

    if (bridges[message.sourceChainSelector] != abi.decode(message.sender, (address))) {
      revert InvalidMessage();
    }

    // if (tokenAmounts[0].token != GHO || tokenAmounts[0].amount == 0) {
    //   revert InvalidMessage();
    // }

    IERC20(GHO).transfer(COLLECTOR, tokenAmounts[0].amount);

    emit TransferFinished(messageId, sender, COLLECTOR, tokenAmounts[0].amount);
  }

  /**
   * @notice Set up destination bridge data
   * @param _destinationChainSelector The selector of the destination chain
   *        chain selector can be found https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet
   * @param _bridge The address of the bridge deployed on destination chain
   */
  function setDestinationBridge(
    uint64 _destinationChainSelector,
    address _bridge
  ) external onlyOwner {
    bridges[_destinationChainSelector] = _bridge;

    emit DestinationUpdated(_destinationChainSelector, _bridge);
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
}
