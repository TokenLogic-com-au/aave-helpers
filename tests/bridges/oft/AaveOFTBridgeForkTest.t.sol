// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';

import {OFTConstants} from './Constants.sol';
import {AaveOFTBridgeSteward} from 'src/bridges/oft/AaveOFTBridgeSteward.sol';
import {IAaveOFTBridgeSteward} from 'src/bridges/oft/interfaces/IAaveOFTBridgeSteward.sol';

/**
 * @title AaveOFTBridgeForkTest
 * @notice Fork tests for USDT0 OFT bridge via LayerZero V2
 */
contract AaveOFTBridgeForkTestBase is Test, OFTConstants {
  uint256 public constant LARGE_BRIDGE_AMOUNT = 10_000_000e6; // 10 million USDT
  uint256 public constant BRIDGE_AMOUNT = 1000e6; // 1000 USDT
  uint256 public maxFee;

  uint256 public mainnetFork;
  uint256 public arbitrumFork;

  address public owner = makeAddr('owner');
  address public guardian = makeAddr('guardian');
  address public receiver;

  AaveOFTBridgeSteward public mainnetBridge;
  AaveOFTBridgeSteward public arbitrumBridge;

  event Bridge(
    address indexed token,
    uint32 indexed dstEid,
    address indexed receiver,
    uint256 amount,
    uint256 minAmountReceived
  );

  function setUp() public virtual {
    mainnetFork = vm.createSelectFork(vm.rpcUrl('mainnet'));

    mainnetBridge = new AaveOFTBridgeSteward(
      ETHEREUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Ethereum.COLLECTOR)
    );
    receiver = address(AaveV3Arbitrum.COLLECTOR);

    vm.prank(owner);
    mainnetBridge.setAllowedReceiver(receiver, true);

    bytes32 fundsAdminRole = AaveV3Ethereum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    IAccessControl(address(AaveV3Ethereum.COLLECTOR)).grantRole(
      fundsAdminRole,
      address(mainnetBridge)
    );
    maxFee = type(uint256).max;
  }
}

contract QuoteBridgeEthereumToArbitrumTest is AaveOFTBridgeForkTestBase {
  function test_quoteBridge_ethereumToArbitrum() public {
    vm.selectFork(mainnetFork);

    uint256 fee = mainnetBridge.quoteBridge(
      ARBITRUM_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );

    assertGt(fee, 0, 'Fee should be greater than 0');
  }

  function test_quoteOFT_ethereumToArbitrum() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver);

    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');
  }

  function test_quote_ethereumToArbitrum_10MillionUSDT() public {
    vm.selectFork(mainnetFork);

    uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver);
    assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');

    uint256 fee = mainnetBridge.quoteBridge(
      ARBITRUM_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );
    assertGt(fee, 0, 'Fee should be greater than 0');
  }
}

contract BridgeEthereumToArbitrumTest is AaveOFTBridgeForkTestBase {
  function test_bridge_happyPath() public {
    vm.selectFork(mainnetFork);

    deal(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), BRIDGE_AMOUNT);
    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      BRIDGE_AMOUNT,
      'Collector should have USDT'
    );

    uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, BRIDGE_AMOUNT, receiver);
    assertEq(expectedReceived, BRIDGE_AMOUNT, 'OFT should have no slippage');

    uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);
    assertGt(fee, 0, 'Fee should be quoted');

    vm.deal(address(mainnetBridge), fee + 1 ether);
    uint256 oftLockerBalanceBefore = IERC20(ETHEREUM_USDT).balanceOf(mainnetBridge.OFT_USDT());

    vm.expectEmit(true, true, true, true, address(mainnetBridge));
    emit Bridge(ETHEREUM_USDT, ARBITRUM_EID, receiver, BRIDGE_AMOUNT, BRIDGE_AMOUNT);

    vm.prank(owner);
    mainnetBridge.bridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT, fee);

    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)),
      0,
      'Bridge should have 0 USDT after bridging'
    );
    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(mainnetBridge.OFT_USDT()),
      oftLockerBalanceBefore + BRIDGE_AMOUNT,
      'OFT locker should have received bridged USDT'
    );
    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      0,
      'Collector should spend USDT'
    );
  }

  function test_revertsIf_notOwnerOrGuardian() public {
    vm.selectFork(mainnetFork);

    address notOwner = makeAddr('not-owner');

    vm.prank(notOwner);
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, notOwner)
    );
    mainnetBridge.bridge(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT, 0);
  }

  function test_bridge_withMsgValue() public {
    vm.selectFork(mainnetFork);

    address deployer = makeAddr('bridge-deployer');
    vm.prank(deployer);
    AaveOFTBridgeSteward unfundedBridge = new AaveOFTBridgeSteward(
      ETHEREUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Ethereum.COLLECTOR)
    );
    assertEq(address(unfundedBridge).balance, 0, 'Bridge should not be pre-funded');

    vm.prank(owner);
    unfundedBridge.setAllowedReceiver(receiver, true);

    bytes32 fundsAdminRole = AaveV3Ethereum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    IAccessControl(address(AaveV3Ethereum.COLLECTOR)).grantRole(
      fundsAdminRole,
      address(unfundedBridge)
    );

    deal(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), BRIDGE_AMOUNT);

    uint256 fee = unfundedBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);
    vm.deal(owner, fee);

    vm.expectEmit(true, true, true, true, address(unfundedBridge));
    emit Bridge(ETHEREUM_USDT, ARBITRUM_EID, receiver, BRIDGE_AMOUNT, BRIDGE_AMOUNT);

    vm.prank(owner);
    unfundedBridge.bridge{value: fee}(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT, fee);

    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(unfundedBridge)),
      0,
      'Bridge should have 0 USDT after bridging'
    );
    assertEq(address(unfundedBridge).balance, 0, 'Bridge should not have ETH after bridging');
    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      0,
      'Collector should spend USDT'
    );
  }

  function test_bridge_withExactAmount() public {
    vm.selectFork(mainnetFork);
    deal(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), BRIDGE_AMOUNT);

    uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, BRIDGE_AMOUNT, receiver);
    assertEq(expectedReceived, BRIDGE_AMOUNT, 'OFT should have no slippage');

    uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);
    vm.deal(address(mainnetBridge), fee + 1 ether);

    vm.prank(owner);
    mainnetBridge.bridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT, fee);

    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)),
      0,
      'Bridge should have 0 USDT'
    );
  }

  function test_revertsIf_zeroAmount() public {
    vm.selectFork(mainnetFork);

    vm.prank(owner);
    vm.expectRevert(IAaveOFTBridgeSteward.InvalidZeroAmount.selector);
    mainnetBridge.bridge(ARBITRUM_EID, 0, receiver, 0, 0);
  }

  function test_revertsIf_receiverNotAllowed() public {
    vm.selectFork(mainnetFork);

    address disallowedReceiver = makeAddr('disallowed-receiver');

    vm.prank(owner);
    vm.expectRevert(IAaveOFTBridgeSteward.OnlyAllowedRecipients.selector);
    mainnetBridge.bridge(
      ARBITRUM_EID,
      BRIDGE_AMOUNT,
      disallowedReceiver,
      BRIDGE_AMOUNT,
      type(uint256).max
    );
  }

  function test_revertsIf_exceedsMaxFee() public {
    vm.selectFork(mainnetFork);

    deal(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), BRIDGE_AMOUNT);
    uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);
    assertGt(fee, 0, 'Fee should be greater than 0');

    vm.prank(owner);
    vm.expectRevert(IAaveOFTBridgeSteward.ExceedsMaxFee.selector);
    mainnetBridge.bridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT, fee - 1);
  }
}

/**
 * @notice Tests for Arbitrum to Ethereum USDT bridging via USDT0 OFT
 * @dev Arbitrum: OUpgradeable at 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92
 */
contract BridgeArbitrumToEthereumTest is AaveOFTBridgeForkTestBase {
  function setUp() public override {
    arbitrumFork = vm.createSelectFork(vm.rpcUrl('arbitrum'));
    owner = makeAddr('owner');
    guardian = makeAddr('guardian');

    arbitrumBridge = new AaveOFTBridgeSteward(
      ARBITRUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Arbitrum.COLLECTOR)
    );

    vm.prank(owner);
    arbitrumBridge.setAllowedReceiver(address(AaveV3Ethereum.COLLECTOR), true);

    bytes32 fundsAdminRole = AaveV3Arbitrum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Arbitrum.ACL_ADMIN);
    IAccessControl(address(AaveV3Arbitrum.COLLECTOR)).grantRole(
      fundsAdminRole,
      address(arbitrumBridge)
    );
  }

  function test_bridge_arbitrumToEthereum_10MillionUSDT() public {
    vm.selectFork(arbitrumFork);

    address ethReceiver = address(AaveV3Ethereum.COLLECTOR);

    deal(ARBITRUM_USDT, address(AaveV3Arbitrum.COLLECTOR), LARGE_BRIDGE_AMOUNT);
    assertEq(
      IERC20(ARBITRUM_USDT).balanceOf(address(AaveV3Arbitrum.COLLECTOR)),
      LARGE_BRIDGE_AMOUNT,
      'Collector should have USDT'
    );

    uint256 expectedReceived = arbitrumBridge.quoteOFT(
      ETHEREUM_EID,
      LARGE_BRIDGE_AMOUNT,
      ethReceiver
    );
    assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');

    uint256 fee = arbitrumBridge.quoteBridge(
      ETHEREUM_EID,
      LARGE_BRIDGE_AMOUNT,
      ethReceiver,
      LARGE_BRIDGE_AMOUNT
    );
    vm.deal(address(arbitrumBridge), fee + 1 ether);
    uint256 totalSupplyBefore = IERC20(ARBITRUM_USDT).totalSupply();

    vm.expectEmit(true, true, true, true, address(arbitrumBridge));
    emit Bridge(ARBITRUM_USDT, ETHEREUM_EID, ethReceiver, LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT);

    vm.prank(owner);
    arbitrumBridge.bridge(ETHEREUM_EID, LARGE_BRIDGE_AMOUNT, ethReceiver, LARGE_BRIDGE_AMOUNT, fee);

    assertEq(
      IERC20(ARBITRUM_USDT).balanceOf(address(arbitrumBridge)),
      0,
      'Bridge should have 0 USDT after bridging'
    );
    assertEq(
      IERC20(ARBITRUM_USDT).totalSupply(),
      totalSupplyBefore - LARGE_BRIDGE_AMOUNT,
      'USDT should be burned on Arbitrum'
    );
  }
}

contract RescueTokenTest is AaveOFTBridgeForkTestBase {
  function test_rescueToken() public {
    vm.selectFork(mainnetFork);

    uint256 amount = 1_000_000e6;
    deal(ETHEREUM_USDT, address(mainnetBridge), amount);

    uint256 collectorBalanceBefore = IERC20(ETHEREUM_USDT).balanceOf(
      address(AaveV3Ethereum.COLLECTOR)
    );

    vm.prank(owner);
    mainnetBridge.rescueToken(ETHEREUM_USDT);

    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      collectorBalanceBefore + amount,
      'Collector should receive tokens'
    );
    assertEq(
      IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)),
      0,
      'Bridge should have 0 balance'
    );
  }
}

contract TransferOwnershipTest is AaveOFTBridgeForkTestBase {
  function test_transferOwnership() public {
    vm.selectFork(mainnetFork);

    address newOwner = GovernanceV3Ethereum.EXECUTOR_LVL_1;

    vm.prank(owner);
    mainnetBridge.transferOwnership(newOwner);

    assertEq(mainnetBridge.owner(), newOwner, 'Ownership should be transferred');
  }

  function test_transferOwnership_revertsIf_notOwner() public {
    vm.selectFork(mainnetFork);

    address notOwner = makeAddr('not-owner');
    address newOwner = makeAddr('new-owner');

    vm.prank(notOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
    mainnetBridge.transferOwnership(newOwner);
  }

  function test_renounceOwnership() public {
    vm.selectFork(mainnetFork);

    vm.prank(owner);
    mainnetBridge.renounceOwnership();

    assertEq(mainnetBridge.owner(), address(0), 'Owner should be zero address');
  }
}

/**
 * @notice Tests for Ethereum to Plasma USDT bridging via USDT0 OFT
 */
contract QuoteBridgeEthereumToPlasmaTest is AaveOFTBridgeForkTestBase {
  function setUp() public override {
    super.setUp();
    receiver = address(AaveV3Plasma.COLLECTOR);
  }

  function test_quoteBridge_ethereumToPlasma() public {
    vm.selectFork(mainnetFork);

    uint256 fee = mainnetBridge.quoteBridge(
      PLASMA_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );

    assertGt(fee, 0, 'Fee should be greater than 0');
  }

  function test_quoteOFT_ethereumToPlasma() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, LARGE_BRIDGE_AMOUNT, receiver);
    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');
  }

  function test_quote_BRIDGE_AMOUNT_ethereumToPlasma() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, BRIDGE_AMOUNT, receiver);
    uint256 fee = mainnetBridge.quoteBridge(PLASMA_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

    assertGt(fee, 0, 'Fee should be quoted');
    assertEq(amountReceived, BRIDGE_AMOUNT, 'OFT should have no slippage');
  }
}

/**
 * @notice Tests for constructor and immutable values
 */
contract ConstructorAndImmutablesTest is AaveOFTBridgeForkTestBase {
  function test_constructor_setsImmutables() public {
    vm.selectFork(mainnetFork);

    assertEq(mainnetBridge.OFT_USDT(), ETHEREUM_USDT0_OFT, 'OFT_USDT should be set correctly');
    assertEq(mainnetBridge.USDT(), ETHEREUM_USDT, 'USDT should be set correctly');
    assertEq(mainnetBridge.owner(), owner, 'Owner should be set correctly');
    assertEq(mainnetBridge.guardian(), guardian, 'Guardian should be set correctly');
    assertEq(
      mainnetBridge.COLLECTOR(),
      address(AaveV3Ethereum.COLLECTOR),
      'Collector should be set correctly'
    );
  }

  function test_constructor_arbitrumBridge() public {
    arbitrumFork = vm.createSelectFork(vm.rpcUrl('arbitrum'));
    vm.selectFork(arbitrumFork);

    arbitrumBridge = new AaveOFTBridgeSteward(
      ARBITRUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Arbitrum.COLLECTOR)
    );

    assertEq(arbitrumBridge.OFT_USDT(), ARBITRUM_USDT0_OFT, 'OFT_USDT should be set correctly');
    assertEq(arbitrumBridge.USDT(), ARBITRUM_USDT, 'USDT should be set correctly');
    assertEq(arbitrumBridge.owner(), owner, 'Owner should be set correctly');
    assertEq(arbitrumBridge.guardian(), guardian, 'Guardian should be set correctly');
    assertEq(
      arbitrumBridge.COLLECTOR(),
      address(AaveV3Arbitrum.COLLECTOR),
      'Collector should be set correctly'
    );
  }

  function test_constructor_revertsIf_zeroGuardian() public {
    vm.selectFork(mainnetFork);

    vm.expectRevert(IAaveOFTBridgeSteward.InvalidZeroAddress.selector);
    new AaveOFTBridgeSteward(
      ETHEREUM_USDT0_OFT,
      owner,
      address(0),
      address(AaveV3Ethereum.COLLECTOR)
    );
  }

  function test_constructor_revertsIf_zeroCollector() public {
    vm.selectFork(mainnetFork);

    vm.expectRevert(IAaveOFTBridgeSteward.InvalidZeroAddress.selector);
    new AaveOFTBridgeSteward(ETHEREUM_USDT0_OFT, owner, guardian, address(0));
  }

  function test_constructor_revertsIf_zeroOft() public {
    vm.selectFork(mainnetFork);

    vm.expectRevert(IAaveOFTBridgeSteward.InvalidZeroAddress.selector);
    new AaveOFTBridgeSteward(address(0), owner, guardian, address(AaveV3Ethereum.COLLECTOR));
  }

  function test_setAllowedReceiver_revertsIf_zeroReceiver() public {
    vm.selectFork(mainnetFork);

    vm.prank(owner);
    vm.expectRevert(IAaveOFTBridgeSteward.InvalidZeroAddress.selector);
    mainnetBridge.setAllowedReceiver(address(0), true);
  }
}

/**
 * @notice Tests for receive function and native token handling
 */
contract ReceiveFunctionTest is AaveOFTBridgeForkTestBase {
  function test_receive_acceptsNativeTokens() public {
    vm.selectFork(mainnetFork);

    uint256 balanceBefore = address(mainnetBridge).balance;

    address sender = makeAddr('sender');
    vm.deal(sender, 10 ether);

    vm.prank(sender);
    (bool success, ) = address(mainnetBridge).call{value: 1 ether}('');

    assertTrue(success, 'Should accept native tokens');
    assertEq(address(mainnetBridge).balance, balanceBefore + 1 ether, 'Balance should increase');
  }
}

/**
 * @notice Tests for rescue functionality
 */
contract RescuableTest is AaveOFTBridgeForkTestBase {
  function test_maxRescue_returnsBridgeBalance() public {
    vm.selectFork(mainnetFork);

    uint256 amount = 2_500e6;
    deal(ETHEREUM_USDT, address(mainnetBridge), amount);

    assertEq(
      mainnetBridge.maxRescue(ETHEREUM_USDT),
      amount,
      'maxRescue should return bridge token balance'
    );
  }

  function test_rescueToken_revertsIf_notOwnerOrGuardian() public {
    vm.selectFork(mainnetFork);

    address notOwner = makeAddr('not-owner');
    uint256 amount = 1_000e6;
    deal(ETHEREUM_USDT, address(mainnetBridge), amount);

    vm.prank(notOwner);
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, notOwner)
    );
    mainnetBridge.rescueToken(ETHEREUM_USDT);
  }

  function test_rescueEth() public {
    vm.selectFork(mainnetFork);

    uint256 ethAmount = 5 ether;
    vm.deal(address(mainnetBridge), ethAmount);

    uint256 collectorBalanceBefore = address(AaveV3Ethereum.COLLECTOR).balance;

    vm.prank(owner);
    mainnetBridge.rescueEth();

    assertEq(
      address(AaveV3Ethereum.COLLECTOR).balance,
      collectorBalanceBefore + ethAmount,
      'Collector should receive ETH'
    );
    assertEq(address(mainnetBridge).balance, 0, 'Bridge should have 0 ETH balance');
  }
}

/**
 * @notice Tests for Ethereum to Polygon USDT bridging
 */
contract QuoteBridgeEthereumToPolygonTest is AaveOFTBridgeForkTestBase {
  function setUp() public override {
    super.setUp();
    receiver = makeAddr('polygon-receiver');
  }

  function test_quoteBridge_ethereumToPolygon() public {
    vm.selectFork(mainnetFork);

    uint256 fee = mainnetBridge.quoteBridge(
      POLYGON_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );

    assertGt(fee, 0, 'Fee should be greater than 0');
  }

  function test_quoteOFT_ethereumToPolygon() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(POLYGON_EID, LARGE_BRIDGE_AMOUNT, receiver);

    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');
  }
}

/**
 * @notice Tests for Ethereum to Optimism USDT bridging
 */
contract QuoteBridgeEthereumToOptimismTest is AaveOFTBridgeForkTestBase {
  function setUp() public override {
    super.setUp();
    receiver = makeAddr('optimism-receiver');
  }

  function test_quoteBridge_ethereumToOptimism() public {
    vm.selectFork(mainnetFork);

    uint256 fee = mainnetBridge.quoteBridge(
      OPTIMISM_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );

    assertGt(fee, 0, 'Fee should be greater than 0');
  }

  function test_quoteOFT_ethereumToOptimism() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(OPTIMISM_EID, LARGE_BRIDGE_AMOUNT, receiver);
    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');
  }
}

/**
 * @notice Tests for Ethereum to Ink USDT bridging via USDT0 OFT
 */
contract QuoteBridgeEthereumToInkTest is AaveOFTBridgeForkTestBase {
  function setUp() public override {
    super.setUp();
    receiver = makeAddr('ink-receiver');
  }

  function test_quoteBridge_ethereumToInk() public {
    vm.selectFork(mainnetFork);

    uint256 fee = mainnetBridge.quoteBridge(
      INK_EID,
      LARGE_BRIDGE_AMOUNT,
      receiver,
      LARGE_BRIDGE_AMOUNT
    );

    assertGt(fee, 0, 'Fee should be greater than 0');
  }

  function test_quoteOFT_ethereumToInk() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(INK_EID, LARGE_BRIDGE_AMOUNT, receiver);
    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, 'OFT should have no slippage');
  }

  function test_quote_BRIDGE_AMOUNT_ethereumToInk() public {
    vm.selectFork(mainnetFork);

    uint256 amountReceived = mainnetBridge.quoteOFT(INK_EID, BRIDGE_AMOUNT, receiver);
    uint256 fee = mainnetBridge.quoteBridge(INK_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

    assertGt(fee, 0, 'Fee should be quoted');
    assertEq(amountReceived, BRIDGE_AMOUNT, 'OFT should have no slippage');
  }
}
