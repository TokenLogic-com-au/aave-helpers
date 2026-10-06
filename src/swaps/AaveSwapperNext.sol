// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';

import {ERC1271Forwarder} from '../dependencies/cow/ERC1271Forwarder.sol';
import {IComposableCow} from '../interfaces/IComposableCow.sol';
import {IAaveSwapperNext} from './interfaces/IAaveSwapperNext.sol';

/**
 * @title AaveSwapperNext
 * @author halaprix
 * @notice Helper contract to swap assets using cowswap
 */
contract AaveSwapperNext is IAaveSwapperNext, ERC1271Forwarder, OwnableWithGuardian, Rescuable {
  constructor(
    address executor,
    address guardian,
    IComposableCow composableCow
  ) OwnableWithGuardian(executor, guardian) ERC1271Forwarder(composableCow) {}

  /// @inheritdoc IAaveSwapperNext
  function MARKET_ORDER_HANDLER() external view override returns (address) {}

  /// @inheritdoc IAaveSwapperNext
  function VAULT_RELAYER() external view override returns (address) {}

  /// @inheritdoc IAaveSwapperNext
  function COLLECTOR() external view override returns (address) {}

  /// @inheritdoc IAaveSwapperNext
  function APP_DATA() external view override returns (bytes32) {}

  /// @inheritdoc IAaveSwapperNext
  function MAX_SLIPPAGE() external view override returns (uint256) {}

  /// @inheritdoc IAaveSwapperNext
  function swap(SwapParams calldata) external override onlyOwner returns (bytes32) {}

  /// @inheritdoc IAaveSwapperNext
  function cancelSwap(SwapParams calldata) external override onlyOwnerOrGuardian {}

  /// @inheritdoc IAaveSwapperNext
  function getExpectedOut(
    address,
    address,
    address,
    address,
    uint256
  ) external view override returns (uint256) {}

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
