// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BaseConditionalOrder} from '../../dependencies/cow/BaseConditionalOrder.sol';
import {GPv2Order} from '../../dependencies/cow/GPv2Order.sol';

/**
 * @title OracleMarketOrder
 * @author halaprix
 * @notice Conditional order handler that prices a market swap from Chainlink oracles at execution time
 */
contract OracleMarketOrder is BaseConditionalOrder {
  /// @inheritdoc BaseConditionalOrder
  function getTradeableOrder(
    address,
    address,
    bytes32,
    bytes calldata,
    bytes calldata
  ) public view override returns (GPv2Order.Data memory) {}
}
