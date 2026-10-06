// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';

import {AaveSwapperNext} from 'src/swaps/AaveSwapperNext.sol';
import {IComposableCow} from 'src/interfaces/IComposableCow.sol';

contract AaveSwapperNextTest is Test {
  /// https://arbiscan.io/address/0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74#code
  address public constant COMPOSABLE_COW = 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74;
  /// https://arbiscan.io/address/0x9008D19f58AAbD9eD0D60971565AA8510560ab41#code
  address public constant GPV2_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
  /// https://arbiscan.io/address/0xC92E8bdf79f0507f65a392b0ab4667716BFE0110#code
  address public constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

  address public guardian = makeAddr('guardian');

  AaveSwapperNext public swapper;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 512244730);

    swapper = new AaveSwapperNext(
      GovernanceV3Arbitrum.EXECUTOR_LVL_1,
      guardian,
      IComposableCow(COMPOSABLE_COW)
    );
  }
}
