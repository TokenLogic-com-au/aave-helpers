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

  // https://etherscan.io/address/0xBA12222222228d8Ba445958a75a0704d566BF2C8
  address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  // https://balancer.fi/pools/ethereum/v2/0x3de27efa2f1aa663ae5d458857e731c129069f29000200000000000000000588
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
      tokens,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      guardian,
      hypernative
    );
  }

  function _fundAave(address to, uint256 amount) internal {
    deal(AaveV3EthereumAssets.AAVE_UNDERLYING, to, amount);
  }

  function _fundWstEth(address to, uint256 amount) internal {
    deal(AaveV3EthereumAssets.wstETH_UNDERLYING, to, amount);
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
    strategyManager.deposit(POOL_ID, balances);
    vm.stopPrank();
  }

  function test_revertsIf_TokenCountMismatch() public {
    vm.startPrank(guardian);

    uint256[] memory invalidLengthBalances = new uint256[](3);

    vm.expectRevert(IBalancerStrategyManager.TokenCountMismatch.selector);
    strategyManager.deposit(POOL_ID, invalidLengthBalances);
    vm.stopPrank();
  }

  function test_revertsIf_InsufficientFunds() public {
    vm.startPrank(guardian);

    vm.expectRevert(
      abi.encodeWithSelector(
        IBalancerStrategyManager.InsufficientToken.selector,
        AaveV3EthereumAssets.wstETH_UNDERLYING,
        0
      )
    );
    strategyManager.deposit(POOL_ID, balances);
    vm.stopPrank();
  }

  function test_success() public {
    _fundAave(address(strategyManager), 8 ether);
    _fundWstEth(address(strategyManager), 1 ether);
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
    strategyManager.deposit(POOL_ID, balances);
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

    _fundAave(address(strategyManager), 8 ether);
    _fundWstEth(address(strategyManager), 1 ether);

    vm.prank(guardian);
    strategyManager.deposit(POOL_ID, balances);

    (address poolAddress, ) = strategyManager.VAULT().getPool(POOL_ID);

    bptAmount = IERC20(poolAddress).balanceOf(address(strategyManager));
  }

  function test_revertsIf_NotOwnerOrGuardian() public {
    vm.startPrank(alice);

    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    strategyManager.withdraw(POOL_ID, bptAmount);
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
    uint256[] memory amounts = strategyManager.withdraw(POOL_ID, bptAmount);
    vm.stopPrank();

    assertEq(IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(aaveProvider), amounts[1]);
    assertEq(IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(wstEthProvider), amounts[0]);
  }
}

contract EmergencyWithdrawTest is BalancerV2WeightedPoolStrategyManagerTest {
  bytes32[] poolIds;
  function setUp() public override {
    super.setUp();

    uint256[] memory balances = new uint256[](2);
    balances[0] = 1 ether;
    balances[1] = 8 ether;

    _fundAave(address(strategyManager), 8 ether);
    _fundWstEth(address(strategyManager), 1 ether);

    vm.prank(guardian);
    strategyManager.deposit(POOL_ID, balances);

    poolIds = new bytes32[](1);
    poolIds[0] = POOL_ID;
  }

  function test_revertsIf_NotOwnerOrGuardianOrHypernative() public {
    vm.startPrank(alice);

    vm.expectRevert(IBalancerStrategyManager.Unauthorized.selector);
    strategyManager.emergencyWithdraw(poolIds);
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
    uint256[][] memory amounts = strategyManager.emergencyWithdraw(poolIds);
    vm.stopPrank();

    assertEq(IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(aaveProvider), amounts[0][1]);
    assertEq(
      IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).balanceOf(wstEthProvider),
      amounts[0][0]
    );
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
    strategyManager.setTokenProvider(AaveV3EthereumAssets.AAVE_UNDERLYING, newAaveProvider);
    vm.stopPrank();
  }

  function test_success() public {
    address beforeTokenProvider = strategyManager.tokenProvider(
      AaveV3EthereumAssets.AAVE_UNDERLYING
    );

    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);

    strategyManager.setTokenProvider(AaveV3EthereumAssets.AAVE_UNDERLYING, newAaveProvider);
    vm.stopPrank();

    address afterTokenProvider = strategyManager.tokenProvider(
      AaveV3EthereumAssets.AAVE_UNDERLYING
    );
    assertEq(beforeTokenProvider, aaveProvider);
    assertEq(afterTokenProvider, newAaveProvider);
  }
}
