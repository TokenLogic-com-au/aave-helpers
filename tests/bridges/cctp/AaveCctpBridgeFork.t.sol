// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';

import {AaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';
import {IAaveCctpBridge} from 'src/bridges/cctp/interfaces/IAaveCctpBridge.sol';
import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';

contract AaveCctpBridgeForkTest is Test {
  using SafeERC20 for IERC20;

  AaveCctpBridge public bridge;
  IERC20 public usdc;
  address public owner = makeAddr('owner');
  address public guardian = makeAddr('guardian');
  address public collector = address(AaveV3Ethereum.COLLECTOR);
  address public alice = makeAddr('alice');
  address public receiver = makeAddr('receiver');

  uint256 public constant AMOUNT = 10_000e6; // 10k USDC

  function _deployBridge(address bridgeCollector) internal returns (AaveCctpBridge) {
    return
      new AaveCctpBridge(
        CctpConstants.ETHEREUM_TOKEN_MESSENGER,
        CctpConstants.ETHEREUM_USDC,
        owner,
        guardian,
        bridgeCollector
      );
  }

  function _addressToBytes32(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }

  function _fundCollector(uint256 amount) internal {
    deal(address(usdc), collector, amount);
  }

  function setUp() public {
    string memory rpcUrl = vm.envOr('RPC_MAINNET', string(''));
    vm.createSelectFork(rpcUrl);

    usdc = IERC20(CctpConstants.ETHEREUM_USDC);

    bridge = _deployBridge(collector);

    bytes32 fundsAdminRole = AaveV3Ethereum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));

    vm.startPrank(owner);
    bridge.setAllowedReceiver(receiver, true);
    bridge.setAllowedReceiverNonEVM(_addressToBytes32(receiver), true);
    vm.stopPrank();
  }

  function _bridgeToEvm(
    uint32 destinationDomain,
    address destinationReceiver,
    uint256 maxFee,
    IAaveCctpBridge.TransferSpeed speed
  ) internal {
    _fundCollector(AMOUNT);
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit IAaveCctpBridge.Bridge(
      address(usdc),
      destinationDomain,
      _addressToBytes32(destinationReceiver),
      AMOUNT,
      speed
    );

    vm.startPrank(owner);
    bridge.bridge(destinationDomain, AMOUNT, destinationReceiver, maxFee, speed);
    vm.stopPrank();

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore - AMOUNT,
      'Collector should transfer USDC'
    );
  }

  function _bridgeToNonEvm(
    uint32 destinationDomain,
    bytes32 destinationReceiver,
    uint256 maxFee,
    IAaveCctpBridge.TransferSpeed speed
  ) internal {
    _fundCollector(AMOUNT);
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit IAaveCctpBridge.Bridge(
      address(usdc),
      destinationDomain,
      destinationReceiver,
      AMOUNT,
      speed
    );

    vm.startPrank(owner);
    bridge.bridgeNonEvm(destinationDomain, AMOUNT, destinationReceiver, maxFee, speed);
    vm.stopPrank();

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore - AMOUNT,
      'Collector should transfer USDC'
    );
  }

  function test_bridge_fast() public {
    _bridgeToEvm(
      CctpConstants.ARBITRUM_DOMAIN,
      receiver,
      AMOUNT / 100,
      IAaveCctpBridge.TransferSpeed.Fast
    );
  }

  function test_bridge_fast_guardian() public {
    _fundCollector(AMOUNT);
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit IAaveCctpBridge.Bridge(
      address(usdc),
      CctpConstants.ARBITRUM_DOMAIN,
      _addressToBytes32(receiver),
      AMOUNT,
      IAaveCctpBridge.TransferSpeed.Fast
    );

    vm.prank(guardian);
    bridge.bridge(
      CctpConstants.ARBITRUM_DOMAIN,
      AMOUNT,
      receiver,
      AMOUNT / 100,
      IAaveCctpBridge.TransferSpeed.Fast
    );

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore - AMOUNT,
      'Collector should transfer USDC'
    );
  }

  function test_bridge_standard() public {
    _bridgeToEvm(
      CctpConstants.ARBITRUM_DOMAIN,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Standard
    );
  }

  function test_bridge_to_avalanche() public {
    _bridgeToEvm(
      CctpConstants.AVALANCHE_DOMAIN,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Standard
    );
  }

  function test_bridge_to_optimism() public {
    _bridgeToEvm(
      CctpConstants.OPTIMISM_DOMAIN,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Standard
    );
  }

  function test_bridge_to_polygon() public {
    _bridgeToEvm(CctpConstants.POLYGON_DOMAIN, receiver, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_solana() public {
    _bridgeToNonEvm(
      CctpConstants.SOLANA_DOMAIN,
      _addressToBytes32(receiver),
      0,
      IAaveCctpBridge.TransferSpeed.Standard
    );
  }

  function test_bridge_to_unichain() public {
    _bridgeToEvm(
      CctpConstants.UNICHAIN_DOMAIN,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Standard
    );
  }

  function test_bridge_to_linea() public {
    _bridgeToEvm(CctpConstants.LINEA_DOMAIN, receiver, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_base() public {
    _bridgeToEvm(CctpConstants.BASE_DOMAIN, receiver, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_revertsIf_callerNotOwnerOrGuardian() public {
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice)
    );
    bridge.bridge(
      CctpConstants.ARBITRUM_DOMAIN,
      AMOUNT,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_zeroAmount() public {
    vm.startPrank(owner);
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAmount.selector);
    bridge.bridge(
      CctpConstants.ARBITRUM_DOMAIN,
      0,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_receiverNotAllowed() public {
    address unallowedReceiver = makeAddr('unallowedReceiver');

    vm.startPrank(owner);
    vm.expectRevert(IAaveCctpBridge.OnlyAllowedRecipients.selector);
    bridge.bridge(
      CctpConstants.ARBITRUM_DOMAIN,
      AMOUNT,
      unallowedReceiver,
      0,
      IAaveCctpBridge.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_zeroReceiver() public {
    vm.startPrank(owner);
    vm.expectRevert(IAaveCctpBridge.OnlyAllowedRecipients.selector);
    bridge.bridge(
      CctpConstants.ARBITRUM_DOMAIN,
      AMOUNT,
      address(0),
      0,
      IAaveCctpBridge.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_sameDestinationDomain() public {
    vm.startPrank(owner);
    vm.expectRevert(IAaveCctpBridge.InvalidDestinationDomain.selector);
    bridge.bridge(
      CctpConstants.ETHEREUM_DOMAIN,
      AMOUNT,
      receiver,
      0,
      IAaveCctpBridge.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_constructorTokenMessengerZero() public {
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    new AaveCctpBridge(address(0), CctpConstants.ETHEREUM_USDC, owner, guardian, collector);
  }

  function test_revertsIf_constructorUsdcZero() public {
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    new AaveCctpBridge(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      address(0),
      owner,
      guardian,
      collector
    );
  }

  function test_revertsIf_constructorGuardianZero() public {
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    new AaveCctpBridge(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      address(0),
      collector
    );
  }

  function test_revertsIf_constructorCollectorZero() public {
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    new AaveCctpBridge(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      guardian,
      address(0)
    );
  }

  function test_revertsIf_setAllowedReceiverZeroAddress() public {
    vm.prank(owner);
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    bridge.setAllowedReceiver(address(0), true);
  }

  function test_revertsIf_setAllowedReceiverNonEvmZeroAddress() public {
    vm.prank(owner);
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
    bridge.setAllowedReceiverNonEVM(bytes32(0), true);
  }

  function test_rescueToken_guardian() public {
    AaveCctpBridge rescueBridge = _deployBridge(receiver);
    deal(address(usdc), address(rescueBridge), AMOUNT);

    vm.prank(guardian);
    rescueBridge.rescueToken(address(usdc));

    assertEq(usdc.balanceOf(address(rescueBridge)), 0, 'Rescue bridge should have no USDC left');
    assertEq(usdc.balanceOf(receiver), AMOUNT, 'Collector should receive rescued USDC');
  }

  function test_rescueEth_owner() public {
    AaveCctpBridge rescueBridge = _deployBridge(receiver);
    vm.deal(address(this), 1 ether);
    uint256 bridgeBalanceBefore = address(rescueBridge).balance;
    uint256 receiverBalanceBefore = receiver.balance;

    (bool success, ) = address(rescueBridge).call{value: 1 ether}('');
    assertTrue(success, 'Bridge should accept ETH');
    assertEq(
      address(rescueBridge).balance,
      bridgeBalanceBefore + 1 ether,
      'Bridge should hold the transferred ETH before rescue'
    );

    vm.prank(owner);
    rescueBridge.rescueEth();

    assertEq(address(rescueBridge).balance, 0, 'Bridge should have no ETH left');
    assertEq(
      receiver.balance,
      receiverBalanceBefore + bridgeBalanceBefore + 1 ether,
      'Collector should receive rescued ETH'
    );
  }

  function test_maxRescue_returnsFullBalance() public {
    AaveCctpBridge rescueBridge = _deployBridge(receiver);
    deal(address(usdc), address(rescueBridge), AMOUNT);

    assertEq(rescueBridge.maxRescue(address(usdc)), AMOUNT);
  }
}
