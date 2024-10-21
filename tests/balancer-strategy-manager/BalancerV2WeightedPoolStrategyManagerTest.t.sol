// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';

import {IBalancerStrategyManager, BalancerV2WeightedPoolStrategyManager} from 'src/balancer-strategy-manager/BalancerV2WeightedPoolStrategyManager.sol';

contract BalancerV2WeightedPoolStrategyManagerTest is Test {
  event PoolBalanceChanged(
    bytes32 indexed poolId,
    address indexed liquidityProvider,
    IERC20[] tokens,
    int256[] deltas,
    uint256[] protocolFeeAmounts
  );

  address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  bytes32 public constant POOL_ID =
    0x3de27efa2f1aa663ae5d458857e731c129069f29000200000000000000000588;

  address public guardian = makeAddr('guardian');
  address public hypernative = makeAddr('hypernative');
  address public aaveProvider = makeAddr('aave-provider');
  address public wstEthProvider = makeAddr('wstEth-provider');
  address public alice = makeAddr('alice');

  BalancerV2WeightedPoolStrategyManager public strategyManager;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20991650);
    IBalancerStrategyManager.TokenConfig[]
      memory tokens = new IBalancerStrategyManager.TokenConfig[](2);

    tokens[0] = IBalancerStrategyManager.TokenConfig({
      token: AaveV3EthereumAssets.wstETH_UNDERLYING,
      provider: wstEthProvider
    });
    tokens[1] = IBalancerStrategyManager.TokenConfig({
      token: AaveV3EthereumAssets.AAVE_UNDERLYING,
      provider: aaveProvider
    });

    strategyManager = new BalancerV2WeightedPoolStrategyManager(
      BALANCER_VAULT,
      POOL_ID,
      tokens,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      guardian,
      hypernative
    );
  }

  function _fundAaveFromWhale(address to, uint256 amount) internal {
    vm.startPrank(0x4da27a545c0c5B758a6BA100e3a049001de870f5);
    IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).transfer(to, amount);
    vm.stopPrank();
  }

  function _fundWstEthFromWhale(address to, uint256 amount) internal {
    vm.startPrank(0x0B925eD163218f6662a35e0f0371Ac234f9E9371);
    IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).transfer(to, amount);
    vm.stopPrank();
  }
}

contract DepositTest is BalancerV2WeightedPoolStrategyManagerTest {
  uint256[] public balances;

  constructor() {
    balances = new uint256[](2);
    balances[0] = 1 ether;
    balances[1] = 8 ether;
  }

  function test_revertsIf_NotOwnerOrGuardian() public {
    vm.startPrank(alice);

    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    strategyManager.deposit(balances);
    vm.stopPrank();
  }

  function test_revertsIf_TokenCountMismatch() public {
    vm.startPrank(guardian);

    uint256[] memory invalidLengthBalances = new uint256[](3);

    vm.expectRevert(BalancerV2WeightedPoolStrategyManager.TokenCountMismatch.selector);
    strategyManager.deposit(invalidLengthBalances);
    vm.stopPrank();
  }

  function test_revertsIf_InsufficientFunds() public {
    vm.startPrank(guardian);

    vm.expectRevert(
      abi.encodeWithSelector(
        BalancerV2WeightedPoolStrategyManager.InsufficientToken.selector,
        AaveV3EthereumAssets.wstETH_UNDERLYING
      )
    );
    strategyManager.deposit(balances);
    vm.stopPrank();
  }

  function test_success() public {
    _fundAaveFromWhale(address(strategyManager), 8 ether);
    _fundWstEthFromWhale(address(strategyManager), 1 ether);
    vm.startPrank(guardian);

    assertEq(
      IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(address(strategyManager)),
      8 ether
    );
    assertEq(
      IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(address(strategyManager)),
      1 ether
    );

    vm.expectEmit(true, true, false, false, BALANCER_VAULT);
    emit PoolBalanceChanged(
      POOL_ID,
      address(strategyManager),
      new IERC20[](2),
      new int256[](2),
      new uint256[](2)
    );
    strategyManager.deposit(balances);
    vm.stopPrank();

    assertEq(IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(address(strategyManager)), 0);
    assertEq(IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(address(strategyManager)), 0);
  }
}

contract WithdrawTest is BalancerV2WeightedPoolStrategyManagerTest {
  uint256 public bptAmount;
  function setUp() public override {
    super.setUp();

    uint256[] memory balances = new uint256[](2);
    balances[0] = 1 ether;
    balances[1] = 8 ether;

    _fundAaveFromWhale(address(strategyManager), 8 ether);
    _fundWstEthFromWhale(address(strategyManager), 1 ether);

    vm.prank(guardian);
    strategyManager.deposit(balances);

    bptAmount = IERC20(address(strategyManager.POOL())).balanceOf(address(strategyManager));
  }

  function test_revertsIf_NotOwnerOrGuardian() public {
    vm.startPrank(alice);

    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    strategyManager.withdraw(bptAmount);
    vm.stopPrank();
  }

  function test_success() public {
    vm.startPrank(guardian);

    vm.expectEmit(true, true, false, false, BALANCER_VAULT);
    emit PoolBalanceChanged(
      POOL_ID,
      address(strategyManager),
      new IERC20[](2),
      new int256[](2),
      new uint256[](2)
    );
    uint256[] memory amounts = strategyManager.withdraw(bptAmount);
    vm.stopPrank();

    assertEq(IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(aaveProvider), amounts[1]);
    assertEq(IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(wstEthProvider), amounts[0]);
  }
}

contract EmergencyWithdrawTest is BalancerV2WeightedPoolStrategyManagerTest {
  function setUp() public override {
    super.setUp();

    uint256[] memory balances = new uint256[](2);
    balances[0] = 1 ether;
    balances[1] = 8 ether;

    _fundAaveFromWhale(address(strategyManager), 8 ether);
    _fundWstEthFromWhale(address(strategyManager), 1 ether);

    vm.prank(guardian);
    strategyManager.deposit(balances);
  }

  function test_revertsIf_NotOwnerOrGuardianOrHypernative() public {
    vm.startPrank(alice);

    vm.expectRevert(BalancerV2WeightedPoolStrategyManager.AccessForbidden.selector);
    strategyManager.emergencyWithdraw();
    vm.stopPrank();
  }

  function test_success() public {
    vm.startPrank(guardian);

    vm.expectEmit(true, true, false, false, BALANCER_VAULT);
    emit PoolBalanceChanged(
      POOL_ID,
      address(strategyManager),
      new IERC20[](2),
      new int256[](2),
      new uint256[](2)
    );
    uint256[] memory amounts = strategyManager.emergencyWithdraw();
    vm.stopPrank();

    assertEq(IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(aaveProvider), amounts[1]);
    assertEq(IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(wstEthProvider), amounts[0]);
  }
}

contract SetTokenProviderTest is BalancerV2WeightedPoolStrategyManagerTest {
  address public newAaveProvider;

  function setUp() public override {
    super.setUp();

    newAaveProvider = makeAddr('new-aave-provider');
  }

  function test_revertsIf_NotOwner() public {
    vm.startPrank(alice);

    vm.expectRevert('Ownable: caller is not the owner');
    strategyManager.setTokenProvider(1, newAaveProvider);
    vm.stopPrank();
  }

  function test_success() public {
    IBalancerStrategyManager.TokenConfig memory beforeTokenConfig = strategyManager.getTokenConfig(
      1
    );

    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);

    strategyManager.setTokenProvider(1, newAaveProvider);
    vm.stopPrank();

    IBalancerStrategyManager.TokenConfig memory afterTokenConfig = strategyManager.getTokenConfig(
      1
    );
    assertEq(beforeTokenConfig.provider, aaveProvider);
    assertEq(afterTokenConfig.provider, newAaveProvider);
  }
}
