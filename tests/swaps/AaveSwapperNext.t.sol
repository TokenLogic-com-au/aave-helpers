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

  function test_constructor() public {}

  function test_transferOwnership_revertsWith_OwnableUnauthorizedAccount() public {}

  function test_transferOwnership() public {}

  function test_updateGuardian_revertsWith_OnlyGuardianOrOwnerInvalidCaller() public {}

  function test_updateGuardian() public {}

  function test_updateGuardian_toZeroAddress() public {}

  function test_emergencyTokenTransfer_revertsWith_OnlyRescueGuardian() public {}

  function test_emergencyTokenTransfer() public {}

  function test_swap_revertsWith_OwnableUnauthorizedAccount() public {}

  function test_swap_revertsWith_Invalid0xAddress_fromToken() public {}

  function test_swap_revertsWith_Invalid0xAddress_toToken() public {}

  function test_swap_revertsWith_InvalidAmount() public {}

  function test_swap_revertsWith_InvalidRecipient() public {}

  function test_swap_revertsWith_InvalidSlippage() public {}

  function test_swap_revertsWith_OracleNotSet() public {}

  function test_swap_revertsWith_SwapAlreadyPending() public {}

  function test_swap() public {}

  function test_cancelSwap_revertsWith_OnlyGuardianOrOwnerInvalidCaller() public {}

  function test_cancelSwap_revertsWith_SwapNotFound() public {}

  function test_cancelSwap() public {}

  function test_cancelSwap_afterSettlement() public {}

  function test_isValidSignature_revertsWith_InvalidHash() public {}

  function test_isValidSignature_revertsWith_SingleOrderNotAuthed_afterCancel() public {}

  function test_isValidSignature() public {}

  function test_getExpectedOut_revertsWith_OracleNotSet_fromOracle() public {}

  function test_getExpectedOut_revertsWith_OracleNotSet_toOracle() public {}

  function test_getExpectedOut() public {}

  function test_settle() public {}

  function test_settle_revertsWith_OrderNotValid_worseBuyAmount() public {}

  function test_settle_sameValidToBucket() public {}

  function test_settle_revertsWith_OrderNotValid_afterBucketChange() public {}

  function test_settle_revertsWith_OrderNotValid_afterOracleRoundChange() public {}
}
