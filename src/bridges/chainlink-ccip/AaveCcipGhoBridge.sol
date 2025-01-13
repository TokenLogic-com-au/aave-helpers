// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {AccessControl, IAccessControl} from 'aave-v3-origin/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {CCIPReceiver, IAny2EVMMessageReceiver, IERC165} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';

import {IAaveCcipGhoBridge} from './IAaveCcipGhoBridge.sol';

/**
 * @title AaveCcipGhoBridge
 * @author LucasWongC
 * @notice Helper contract to bridge GHO using Chainlink CCIP
 * @dev Sends GHO to AAVE collector of destination chain using chainlink CCIP
 */
contract AaveCcipGhoBridge is IAaveCcipGhoBridge, CCIPReceiver, AccessControl, Rescuable {
  using SafeERC20 for IERC20;

  /// @dev This role defines which users can call bridge functions.
  bytes32 public constant BRIDGER_ROLE = keccak256('AaveCcipGhoBridge.bridger');

  /// @dev Chainlink CCIP router address
  address public immutable ROUTER;
  /// @dev GHO token address
  address public immutable GHO;
  /// @dev Aave Collector address
  address public immutable COLLECTOR;
  /// @dev Aave Executor address
  address public immutable EXECUTOR;

  /// @dev Address of bridge (chainSelector => bridge address)
  mapping(uint64 selector => address bridge) public bridges;

  /// @dev Saves invalid message
  mapping(bytes32 messageId => Client.EVMTokenAmount[] message) private invalidTokenTransfers;
  /// @dev Saves state of invalid message.
  mapping(bytes32 messageId => bool failed) public isInvalidMessage;

  /// @dev Checks if the destination bridge has been set up
  modifier checkDestination(uint64 chainSelector) {
    if (bridges[chainSelector] == address(0)) {
      revert UnsupportedChain();
    }
    _;
  }

  /// @dev Checks if invalid message exist
  modifier checkInvalidMessage(bytes32 messageId) {
    if (!isInvalidMessage[messageId]) {
      revert MessageNotFound();
    }
    _;
  }

  /**
   * @dev Modifier to allow only the contract itself to execute a function.
   *      Throws an exception if called by any account other than the contract itself.
   */
  modifier onlySelf() {
    if (msg.sender != address(this)) revert OnlySelf();
    _;
  }

  /**
   * @param _router The address of the Chainlink CCIP router
   * @param _gho The address of the GHO token
   * @param _collector The address of collector on same chain
   * @param _executor The address of the contract executor
   */
  constructor(
    address _router,
    address _gho,
    address _collector,
    address _executor
  ) CCIPReceiver(_router) {
    ROUTER = _router;
    GHO = _gho;
    COLLECTOR = _collector;
    EXECUTOR = _executor;

    _setupRole(DEFAULT_ADMIN_ROLE, _executor);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public pure virtual override(AccessControl, CCIPReceiver) returns (bool) {
    return
      interfaceId == type(IAccessControl).interfaceId ||
      interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function bridge(
    uint64 destinationChainSelector,
    uint256 amount,
    uint256 gasLimit,
    address feeToken
  )
    external
    payable
    checkDestination(destinationChainSelector)
    onlyRole(BRIDGER_ROLE)
    returns (bytes32 messageId)
  {
    Client.EVM2AnyMessage memory message = _buildCCIPMessage(
      destinationChainSelector,
      amount,
      gasLimit,
      feeToken
    );

    uint256 fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);

    uint256 inBalance = IERC20(GHO).balanceOf(address(this));
    uint256 totalGhoAmount = amount;

    if (feeToken == address(0)) {
      if (msg.value < fee) revert InsufficientNativeFee();
    } else if (feeToken == GHO) {
      totalGhoAmount += fee;
    } else {
      // IERC20(feeToken).transferFrom(msg.sender, address(this), fee);
      // IERC20(feeToken).approve(ROUTER, fee);
      revert InvalidFeeToken();
    }

    if (inBalance < totalGhoAmount) {
      IERC20(GHO).transferFrom(msg.sender, address(this), totalGhoAmount - inBalance);
    }
    IERC20(GHO).approve(ROUTER, totalGhoAmount);

    messageId = IRouterClient(ROUTER).ccipSend{value: feeToken == address(0) ? fee : 0}(
      destinationChainSelector,
      message
    );

    if (feeToken == address(0)) {
      if (msg.value > fee) {
        payable(msg.sender).transfer(msg.value - fee);
      }
    } else {
      payable(msg.sender).transfer(msg.value);
    }

    emit TransferIssued(messageId, destinationChainSelector, msg.sender, amount);
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function quoteBridge(
    uint64 destinationChainSelector,
    uint256 amount,
    uint256 gasLimit,
    address feeToken
  ) external view checkDestination(destinationChainSelector) returns (uint256 fee) {
    Client.EVM2AnyMessage memory message = _buildCCIPMessage(
      destinationChainSelector,
      amount,
      gasLimit,
      feeToken
    );

    fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);
  }

  /**
   * @dev Builds ccip message for token transfer
   */
  function _buildCCIPMessage(
    uint64 destinationChainSelector,
    uint256 amount,
    uint256 gasLimit,
    address feeToken
  ) internal view returns (Client.EVM2AnyMessage memory message) {
    if (amount == 0) {
      revert InvalidTransferAmount();
    }
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: amount});

    message = Client.EVM2AnyMessage({
      receiver: abi.encode(bridges[destinationChainSelector]),
      data: '',
      tokenAmounts: tokenAmounts,
      extraArgs: gasLimit == 0
        ? bytes('')
        : Client._argsToBytes(
          Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: false})
        ),
      feeToken: feeToken
    });
  }

  /// @inheritdoc CCIPReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter {
    try this.processMessage(message) {} catch {
      bytes32 messageId = message.messageId;

      Client.EVMTokenAmount[] memory tokenAmounts = message.destTokenAmounts;
      uint256 length = tokenAmounts.length;
      for (uint256 i = 0; i < length; ) {
        invalidTokenTransfers[messageId].push(tokenAmounts[i]);

        unchecked {
          ++i;
        }
      }
      isInvalidMessage[messageId] = true;

      emit ReceivedInvalidMessage(messageId);
    }
  }

  /// @dev wrap _ccipReceive as a external function
  function processMessage(Client.Any2EVMMessage calldata message) external onlySelf {
    if (bridges[message.sourceChainSelector] != abi.decode(message.sender, (address))) {
      revert();
    }

    _ccipReceive(message);
  }

  /// @inheritdoc CCIPReceiver
  function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
    bytes32 messageId = message.messageId;
    Client.EVMTokenAmount[] memory tokenAmounts = message.destTokenAmounts;

    IERC20(GHO).transfer(COLLECTOR, tokenAmounts[0].amount);

    emit TransferFinished(messageId, COLLECTOR, tokenAmounts[0].amount);
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function getInvalidMessage(
    bytes32 messageId
  )
    external
    view
    checkInvalidMessage(messageId)
    returns (Client.EVMTokenAmount[] memory tokenAmounts)
  {
    uint256 length = invalidTokenTransfers[messageId].length;
    tokenAmounts = new Client.EVMTokenAmount[](length);

    for (uint256 i = 0; i < length; ) {
      tokenAmounts[i] = invalidTokenTransfers[messageId][i];

      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IAaveCcipGhoBridge
  function handleInvalidMessage(
    bytes32 messageId
  ) external onlyRole(DEFAULT_ADMIN_ROLE) checkInvalidMessage(messageId) {
    isInvalidMessage[messageId] = false;

    Client.EVMTokenAmount[] memory tokenAmounts = invalidTokenTransfers[messageId];
    uint256 length = tokenAmounts.length;
    for (uint256 i = 0; i < length; ) {
      IERC20(tokenAmounts[i].token).safeTransfer(COLLECTOR, tokenAmounts[i].amount);

      unchecked {
        ++i;
      }
    }

    emit HandledInvalidMessage(messageId);
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
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    bridges[_destinationChainSelector] = _bridge;

    emit DestinationUpdated(_destinationChainSelector, _bridge);
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return EXECUTOR;
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(
    address
  ) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
    return type(uint256).max;
  }
}
