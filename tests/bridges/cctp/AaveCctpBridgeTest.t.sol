// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

import {AaveCctpBridge, IAaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';
import {ICctpMessageTransmitter} from './ICctpMessageTransmitter.sol';

contract AaveCctpBridgeTest is Test {
  /// @notice Emitted when new bridge message sent
  event BridgeMessageSent(uint32 toChainId, uint256 amount);
  /// @notice Emitted when redeem token on receiving chain
  event BridgeMessageReceived(bytes message);
  /// @notice Emitted when collector address updated
  event CollectorUpdated(uint32 toChainId, address collector);

  uint256 public sourceFork;
  uint256 public destinationFork;
  address public alice;
  address public bob;
  uint256 bobPrivateKey;

  uint256 amountToSend = 1_000e6;
  AaveCctpBridge sourceBridge;
  AaveCctpBridge destinationBridge;
  uint32 sourceChainId = 0;
  uint32 destinationChainId = 3;

  bytes message;

  function setUp() public {
    destinationFork = vm.createSelectFork(vm.rpcUrl('arbitrum'));
    sourceFork = vm.createFork(vm.rpcUrl('mainnet'));

    (bob, bobPrivateKey) = makeAddrAndKey('bob');
    alice = makeAddr('alice');

    destinationBridge = new AaveCctpBridge(
      0x19330d10D9Cc8751218eaf51E8885D058642E08A, // https://arbiscan.io/address/0x19330d10D9Cc8751218eaf51E8885D058642E08A
      0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca, // https://arbiscan.io/address/0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca
      AaveV3ArbitrumAssets.USDCn_UNDERLYING,
      address(this),
      alice
    );

    // set bob as an Attester
    ICctpMessageTransmitter messageTransmitter = ICctpMessageTransmitter(
      address(destinationBridge.MESSAGE_TRANSMITTER())
    );
    address attesterManager = messageTransmitter.attesterManager();

    vm.startPrank(attesterManager);
    messageTransmitter.enableAttester(bob);
    messageTransmitter.setSignatureThreshold(1);
    vm.stopPrank();

    vm.selectFork(sourceFork);
    sourceBridge = new AaveCctpBridge(
      0xBd3fa81B58Ba92a82136038B25aDec7066af3155, // https://etherscan.io/address/0xBd3fa81B58Ba92a82136038B25aDec7066af3155
      0x0a992d191DEeC32aFe36203Ad87D7d289a738F81, // https://etherscan.io/address/0x0a992d191DEeC32aFe36203Ad87D7d289a738F81
      AaveV3EthereumAssets.USDC_UNDERLYING,
      address(this),
      alice
    );

    deal(AaveV3EthereumAssets.USDC_UNDERLYING, address(sourceBridge), amountToSend);

    vm.startPrank(alice);
    IERC20(AaveV3EthereumAssets.USDC_UNDERLYING).approve(address(sourceBridge), amountToSend);
    vm.stopPrank();

    vm.deal(alice, 1 ether); // add native funds for native-fee test
  }
}

contract BridgeTokenTest is AaveCctpBridgeTest {
  function test_revertsIf_UnsupportedChain() external {
    vm.selectFork(sourceFork);

    vm.startPrank(alice);
    vm.expectRevert(IAaveCctpBridge.InvalidChain.selector);
    sourceBridge.bridgeUsdc(destinationChainId, amountToSend);
  }

  function test_revertsIf_NotOwnerOrGuardian() external {
    vm.selectFork(sourceFork);
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));

    vm.startPrank(bob);
    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    sourceBridge.bridgeUsdc(destinationChainId, amountToSend);
  }

  function test_revertsIf_ZeroAmount() external {
    vm.selectFork(sourceFork);
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));

    vm.startPrank(alice);
    vm.expectRevert(IAaveCctpBridge.ZeroAmount.selector);
    sourceBridge.bridgeUsdc(destinationChainId, 0);
  }

  function test_revertsIf_Insufficient() external {
    vm.selectFork(sourceFork);
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));

    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IAaveCctpBridge.InsufficientBalance.selector, amountToSend)
    );
    sourceBridge.bridgeUsdc(destinationChainId, amountToSend + 1);
  }

  function test_success() external {
    vm.selectFork(sourceFork);
    uint256 beforeBalance = IERC20(AaveV3EthereumAssets.USDC_UNDERLYING).balanceOf(
      address(sourceBridge)
    );
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));

    vm.recordLogs();
    vm.startPrank(alice);
    vm.expectEmit(true, true, true, true, address(sourceBridge));
    emit BridgeMessageSent(destinationChainId, amountToSend);
    sourceBridge.bridgeUsdc(destinationChainId, amountToSend);
    Vm.Log[] memory logs = vm.getRecordedLogs();

    uint256 afterBalance = IERC20(AaveV3EthereumAssets.USDC_UNDERLYING).balanceOf(
      address(sourceBridge)
    );
    assertEq(afterBalance, beforeBalance - amountToSend);

    // get message
    for (uint256 i = 0; i < logs.length; ++i) {
      bytes32 MessageSentTopic = keccak256('MessageSent(bytes)');

      if (logs[i].topics[0] == MessageSentTopic) {
        (message) = abi.decode(logs[i].data, (bytes));
        break;
      }
    }

    bytes32 digest = keccak256(abi.encodePacked(message));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.selectFork(destinationFork);

    beforeBalance = IERC20(AaveV3ArbitrumAssets.USDCn_UNDERLYING).balanceOf(
      address(AaveV3Arbitrum.COLLECTOR)
    );

    vm.startPrank(alice);
    vm.expectEmit(true, true, true, true, address(destinationBridge));
    emit BridgeMessageReceived(message);
    destinationBridge.receiveUsdc(message, signature);

    afterBalance = IERC20(AaveV3ArbitrumAssets.USDCn_UNDERLYING).balanceOf(
      address(AaveV3Arbitrum.COLLECTOR)
    );
    assertEq(afterBalance, beforeBalance + amountToSend);

    vm.stopPrank();
  }
}

contract SetCollectorTest is AaveCctpBridgeTest {
  function test_revertIf_NotOwner() external {
    vm.selectFork(sourceFork);
    vm.startPrank(alice);

    vm.expectRevert('Ownable: caller is not the owner');
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));
    vm.stopPrank();
  }

  function test_success() external {
    vm.selectFork(sourceFork);

    vm.expectEmit(true, true, false, false, address(sourceBridge));
    emit CollectorUpdated(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));
    sourceBridge.setCollector(destinationChainId, address(AaveV3Arbitrum.COLLECTOR));
    vm.stopPrank();
  }
}
