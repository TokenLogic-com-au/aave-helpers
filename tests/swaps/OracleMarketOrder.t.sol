// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {OracleMarketOrder} from 'src/swaps/handlers/OracleMarketOrder.sol';

contract OracleMarketOrderTest is Test {
  OracleMarketOrder public handler;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 512244730);

    handler = new OracleMarketOrder();
  }

  function test_supportsInterface() public {}

  function test_getTradeableOrder() public {}

  function test_getTradeableOrder_decimals() public {}

  function test_fuzz_getTradeableOrder_slippage() public {}

  function test_getTradeableOrder_validToBucketed() public {}

  function test_getTradeableOrder_revertsWith_OrderNotValid_invalidPrice() public {}

  function test_getTradeableOrder_revertsWith_OrderNotValid_zeroBuyAmount() public {}

  function test_getTradeableOrder_revertsWith_OrderNotValid_sequencerDown() public {}

  function test_getTradeableOrder_revertsWith_OrderNotValid_gracePeriodNotOver() public {}

  function test_verify() public {}

  function test_verify_revertsWith_OrderNotValid_invalidHash() public {}
}
