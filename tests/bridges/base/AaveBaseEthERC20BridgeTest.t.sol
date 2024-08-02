// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Base, AaveV3BaseAssets} from 'aave-address-book/AaveV3Base.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';

import {AaveBaseEthERC20Bridge} from 'src/bridges/base/AaveBaseEthERC20Bridge.sol';
import {IAaveBaseEthERC20Bridge} from 'src/bridges/base/IAaveBaseEthERC20Bridge.sol';

contract AaveBaseEthERC20BridgeTest is Test {
  event Bridge(
    address indexed token,
    address indexed l1token,
    uint256 amount,
    address indexed to,
    uint256 nonce
  );

  AaveBaseEthERC20Bridge bridge;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('base'), 17908723);

    bytes32 salt = keccak256(abi.encode(tx.origin, uint256(0)));
    bridge = new AaveBaseEthERC20Bridge{salt: salt}(address(this));
  }
}

contract BridgeTest is AaveBaseEthERC20BridgeTest {
  function test_revertsIf_invalidChain() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20110401);
    bytes32 salt = keccak256(abi.encode(tx.origin, uint256(0)));
    AaveBaseEthERC20Bridge mainnetBridge = new AaveBaseEthERC20Bridge{salt: salt}(address(this));

    vm.expectRevert(IAaveBaseEthERC20Bridge.InvalidChain.selector);
    mainnetBridge.bridge(
      AaveV3BaseAssets.USDC_UNDERLYING,
      AaveV3EthereumAssets.USDC_UNDERLYING,
      1_000e6
    );
  }

  function test_revertsIf_notOwner() public {
    uint256 amount = 1_000e6;

    deal(AaveV3BaseAssets.USDC_UNDERLYING, address(bridge), amount);

    bridge.transferOwnership(GovernanceV3Base.EXECUTOR_LVL_1);

    vm.expectRevert('Ownable: caller is not the owner');
    bridge.bridge(
      AaveV3BaseAssets.USDC_UNDERLYING,
      AaveV3EthereumAssets.USDC_UNDERLYING,
      1_000e6
    );
  }

  function test_successful() public {
    uint256 amount = 1_000e6;

    deal(AaveV3BaseAssets.USDC_UNDERLYING, address(bridge), amount);

    bridge.transferOwnership(GovernanceV3Base.EXECUTOR_LVL_1);

    vm.startPrank(GovernanceV3Base.EXECUTOR_LVL_1);
    vm.expectEmit();
    emit Bridge(
      AaveV3BaseAssets.USDC_UNDERLYING,
      AaveV3EthereumAssets.USDC_UNDERLYING,
      amount,
      address(AaveV3Ethereum.COLLECTOR),
      0
    );
    bridge.bridge(
      AaveV3BaseAssets.USDC_UNDERLYING,
      AaveV3EthereumAssets.USDC_UNDERLYING,
      1_000e6
    );
    vm.stopPrank();
  }
}

contract TransferOwnership is AaveBaseEthERC20BridgeTest {
  function test_revertsIf_invalidCaller() public {
    vm.startPrank(makeAddr('random-caller'));
    vm.expectRevert('Ownable: caller is not the owner');
    bridge.transferOwnership(makeAddr('new-admin'));
    vm.stopPrank();
  }

  function test_successful() public {
    address newAdmin = GovernanceV3Base.EXECUTOR_LVL_1;
    bridge.transferOwnership(newAdmin);

    assertEq(newAdmin, bridge.owner());
  }
}

contract EmergencyTokenTransfer is AaveBaseEthERC20BridgeTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert('ONLY_RESCUE_GUARDIAN');
    vm.startPrank(makeAddr('random-caller'));
    bridge.emergencyTokenTransfer(
      AaveV3BaseAssets.USDC_UNDERLYING,
      address(AaveV3Base.COLLECTOR),
      1_000e6
    );
    vm.stopPrank();
  }

  function test_successful_governanceCaller() public {
    assertEq(IERC20(AaveV3BaseAssets.USDC_UNDERLYING).balanceOf(address(bridge)), 0);

    uint256 usdcAmount = 1_000e18;

    deal(AaveV3BaseAssets.USDC_UNDERLYING, address(bridge), usdcAmount);

    assertEq(IERC20(AaveV3BaseAssets.USDC_UNDERLYING).balanceOf(address(bridge)), usdcAmount);

    uint256 initialCollectorBalBalance = IERC20(AaveV3BaseAssets.USDC_UNDERLYING).balanceOf(
      address(AaveV3Base.COLLECTOR)
    );

    bridge.emergencyTokenTransfer(
      AaveV3BaseAssets.USDC_UNDERLYING,
      address(AaveV3Base.COLLECTOR),
      usdcAmount
    );

    assertEq(
      IERC20(AaveV3BaseAssets.USDC_UNDERLYING).balanceOf(address(AaveV3Base.COLLECTOR)),
      initialCollectorBalBalance + usdcAmount
    );
    assertEq(IERC20(AaveV3BaseAssets.USDC_UNDERLYING).balanceOf(address(bridge)), 0);
  }
}
