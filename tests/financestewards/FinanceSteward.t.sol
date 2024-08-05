// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {FinanceSteward} from '../../src/financestewards/FinanceSteward.sol';

/**
 * @dev Test for Finance Steward contract
 * command: make test contract-filter=FinanceSteward
 */

contract FinanceSteward_Test is Test {
  address public constant guardian = address(42);
  FinanceSteward public steward;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    steward = new FinanceSteward(
      AaveGovernanceV2.SHORT_EXECUTOR,
      guardian
    );
  }
}
