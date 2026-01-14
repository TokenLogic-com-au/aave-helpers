// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';

import {AaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';
import {IAaveCctpBridge} from 'src/bridges/cctp/interfaces/IAaveCctpBridge.sol';
import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';

contract AaveCctpBridgeForkTest is Test {
  using SafeERC20 for IERC20;

  AaveCctpBridge public bridge;
  IERC20 public usdc;
  address public owner = makeAddr('owner');
  address public guardian = makeAddr('guardian');
  address public alice = makeAddr('alice');
  address public receiver = makeAddr('receiver');

  uint256 public constant AMOUNT = 10_000e6; // 10k USDC

  function _addressToBytes32(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }

  function setUp() public {
    string memory rpcUrl = vm.envOr('RPC_MAINNET', string(''));
    vm.createSelectFork(rpcUrl);

    usdc = IERC20(CctpConstants.ETHEREUM_USDC);

    bridge = new AaveCctpBridge(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      guardian
    );

    // Set up collectors for all destination domains
    vm.startPrank(owner);
    bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, receiver);
    bridge.setDestinationCollector(CctpConstants.AVALANCHE_DOMAIN, receiver);
    bridge.setDestinationCollector(CctpConstants.OPTIMISM_DOMAIN, receiver);
    bridge.setDestinationCollector(CctpConstants.BASE_DOMAIN, receiver);
    bridge.setDestinationCollector(CctpConstants.POLYGON_DOMAIN, receiver);
    bridge.setDestinationCollectorNonEVM(CctpConstants.SOLANA_DOMAIN, _addressToBytes32(receiver));
    bridge.setDestinationCollector(CctpConstants.UNICHAIN_DOMAIN, receiver);
    bridge.setDestinationCollector(CctpConstants.LINEA_DOMAIN, receiver);
    vm.stopPrank();
  }

  function _bridgeTo(
    uint32 destinationDomain,
    uint256 maxFee,
    IAaveCctpBridge.TransferSpeed speed
  ) internal {
    deal(address(usdc), owner, AMOUNT);

    vm.startPrank(owner);
    usdc.approve(address(bridge), AMOUNT);
    bridge.bridge(destinationDomain, AMOUNT, maxFee, speed);
    vm.stopPrank();

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(usdc.balanceOf(owner), 0, 'Owner should have no USDC left');
  }

  function test_bridge_fast() public {
    _bridgeTo(CctpConstants.ARBITRUM_DOMAIN, AMOUNT / 100, IAaveCctpBridge.TransferSpeed.Fast);
  }

  function test_bridge_standard() public {
    _bridgeTo(CctpConstants.ARBITRUM_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_avalanche() public {
    _bridgeTo(CctpConstants.AVALANCHE_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_optimism() public {
    _bridgeTo(CctpConstants.OPTIMISM_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_polygon() public {
    _bridgeTo(CctpConstants.POLYGON_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_solana() public {
    _bridgeTo(CctpConstants.SOLANA_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_unichain() public {
    _bridgeTo(CctpConstants.UNICHAIN_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_linea() public {
    _bridgeTo(CctpConstants.LINEA_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_bridge_to_base() public {
    _bridgeTo(CctpConstants.BASE_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
  }

  function test_revertsIf_callerNotOwnerOrGuardian() public {
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice)
    );
    bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Fast);
    vm.stopPrank();
  }

  function test_revertsIf_zeroAmount() public {
    vm.startPrank(owner);
    vm.expectRevert(IAaveCctpBridge.InvalidZeroAmount.selector);
    bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, 0, 0, IAaveCctpBridge.TransferSpeed.Fast);
    vm.stopPrank();
  }

  function test_revertsIf_collectorNotConfigured() public {
    vm.startPrank(owner);
    uint32 unconfiguredDomain = 99;
    vm.expectRevert(
      abi.encodeWithSelector(IAaveCctpBridge.CollectorNotConfigured.selector, unconfiguredDomain)
    );
    bridge.bridge(unconfiguredDomain, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Fast);
    vm.stopPrank();
  }

  function test_revertsIf_sameDestinationDomain() public {
    vm.startPrank(owner);
    bridge.setDestinationCollector(CctpConstants.ETHEREUM_DOMAIN, receiver);
    vm.expectRevert(IAaveCctpBridge.InvalidDestinationDomain.selector);
    bridge.bridge(CctpConstants.ETHEREUM_DOMAIN, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Fast);
    vm.stopPrank();
  }
}
