// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {CCIPLocalSimulatorFork, Register} from '@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

import {CcipGhoBridge, ICcipGhoBridge} from 'src/bridges/chainlink-ccip/CcipGhoBridge.sol';

contract CcipGhoBridgeTest is Test {
  event TransferIssued(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    uint256 totalAmount
  );

  event DestinationUpdated(uint64 indexed chainSelector, address indexed bridge);

  CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
  uint256 public sourceFork;
  uint256 public destinationFork;
  address public alice;
  address public bob;
  IRouterClient public sourceRouter;
  uint64 public destinationChainSelector;
  IERC20 public sourceLinkToken;

  uint256 amountToSend = 1_000e18;
  CcipGhoBridge sourceBridge;
  CcipGhoBridge destinationBridge;

  function setUp() public {
    destinationFork = vm.createSelectFork(vm.rpcUrl('arbitrum'));
    sourceFork = vm.createFork(vm.rpcUrl('mainnet'));

    bob = makeAddr('bob');
    alice = makeAddr('alice');

    ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
    vm.makePersistent(address(ccipLocalSimulatorFork));

    Register.NetworkDetails memory destinationNetworkDetails = Register.NetworkDetails({
      chainSelector: 4949039107694359620,
      routerAddress: 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8,
      linkAddress: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
      wrappedNativeAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
      ccipBnMAddress: 0xA189971a2c5AcA0DFC5Ee7a2C44a2Ae27b3CF389,
      ccipLnMAddress: 0x30DeCD269277b8094c00B0bacC3aCaF3fF4Da7fB
    });
    ccipLocalSimulatorFork.setNetworkDetails(block.chainid, destinationNetworkDetails);
    destinationChainSelector = destinationNetworkDetails.chainSelector;

    destinationBridge = new CcipGhoBridge(
      destinationNetworkDetails.routerAddress,
      destinationNetworkDetails.linkAddress,
      AaveV3ArbitrumAssets.GHO_UNDERLYING,
      address(this)
    );
    // vm.makePersistent(address(destinationBridge));

    vm.selectFork(sourceFork);
    Register.NetworkDetails memory sourceNetworkDetails = Register.NetworkDetails({
      chainSelector: 5009297550715157269,
      routerAddress: 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
      linkAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
      wrappedNativeAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      ccipBnMAddress: 0xA189971a2c5AcA0DFC5Ee7a2C44a2Ae27b3CF389,
      ccipLnMAddress: 0x30DeCD269277b8094c00B0bacC3aCaF3fF4Da7fB
    });
    ccipLocalSimulatorFork.setNetworkDetails(block.chainid, sourceNetworkDetails);
    sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
    sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

    sourceBridge = new CcipGhoBridge(
      sourceNetworkDetails.routerAddress,
      sourceNetworkDetails.linkAddress,
      AaveV3EthereumAssets.GHO_UNDERLYING,
      address(this)
    );
    // vm.makePersistent(address(sourceBridge));

    vm.startPrank(address(AaveV3Ethereum.COLLECTOR));
    IERC20(AaveV3EthereumAssets.GHO_UNDERLYING).transfer(alice, amountToSend);
    vm.stopPrank();

    vm.startPrank(0xBc10f2E862ED4502144c7d632a3459F49DFCDB5e);
    IERC20(AaveV3EthereumAssets.LINK_UNDERLYING).transfer(alice, 100e18); // get link token from collector for test
    vm.stopPrank();

    vm.startPrank(alice);
    IERC20(AaveV3EthereumAssets.GHO_UNDERLYING).approve(address(sourceBridge), amountToSend);
    IERC20(AaveV3EthereumAssets.LINK_UNDERLYING).approve(address(sourceBridge), 100e18);
    vm.stopPrank();

    vm.deal(alice, 1 ether); // add native funds for native-fee test

    vm.selectFork(destinationFork);
    destinationBridge.setDestinationBridge(
      sourceNetworkDetails.chainSelector,
      address(sourceBridge)
    );
  }
}

contract TansferTokensPayFeesInLinkTest is CcipGhoBridgeTest {
  function test_revertsIf_UnsupportedChain() external {
    vm.selectFork(sourceFork);
    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: amountToSend});

    vm.startPrank(alice);
    vm.expectRevert(ICcipGhoBridge.UnsupportedChain.selector);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.LINK);
  }

  function test_revertsIf_InvalidTransferAmount() external {
    vm.selectFork(sourceFork);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: 0});

    vm.startPrank(alice);
    vm.expectRevert(ICcipGhoBridge.InvalidTransferAmount.selector);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.LINK);
  }

  function test_success() external {
    vm.selectFork(destinationFork);
    uint256 beforeBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(bob);

    vm.selectFork(sourceFork);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: amountToSend});

    vm.startPrank(alice);
    vm.expectEmit(false, true, false, true, address(sourceBridge));
    emit TransferIssued(bytes32(0), destinationChainSelector, amountToSend);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.LINK);

    ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
    uint256 afterBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(bob);
    assertEq(afterBalance, beforeBalance + amountToSend);
  }
}

contract TansferTokensPayFeesInNativeTest is CcipGhoBridgeTest {
  function test_revertsIf_UnsupportedChain() external {
    vm.selectFork(sourceFork);
    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: amountToSend});

    vm.startPrank(alice);
    vm.expectRevert(ICcipGhoBridge.UnsupportedChain.selector);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.Native);
  }

  function test_revertsIf_InvalidTransferAmount() external {
    vm.selectFork(sourceFork);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: 0});

    vm.startPrank(alice);
    vm.expectRevert(ICcipGhoBridge.InvalidTransferAmount.selector);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.Native);
  }

  function test_revertsIf_InsufficientFee() external {
    vm.selectFork(sourceFork);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: amountToSend});

    vm.startPrank(alice);
    vm.expectRevert(ICcipGhoBridge.InsufficientFee.selector);
    sourceBridge.transfer(destinationChainSelector, transfers, ICcipGhoBridge.PayFeesIn.Native);
  }

  function test_success() external {
    vm.selectFork(destinationFork);
    uint256 beforeBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(bob);

    vm.selectFork(sourceFork);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    ICcipGhoBridge.Transfer[] memory transfers = new ICcipGhoBridge.Transfer[](1);
    transfers[0] = ICcipGhoBridge.Transfer({to: bob, amount: amountToSend});

    uint256 fee = sourceBridge.quoteTransfer(
      destinationChainSelector,
      transfers,
      ICcipGhoBridge.PayFeesIn.Native
    );

    vm.startPrank(alice);
    vm.expectEmit(false, true, false, true, address(sourceBridge));
    emit TransferIssued(bytes32(0), destinationChainSelector, amountToSend);
    sourceBridge.transfer{value: fee}(
      destinationChainSelector,
      transfers,
      ICcipGhoBridge.PayFeesIn.Native
    );

    ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
    uint256 afterBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(bob);
    assertEq(afterBalance, beforeBalance + amountToSend);
  }
}

contract SetDestinationBridgeTest is CcipGhoBridgeTest {
  function test_revertIf_NotOwner() external {
    vm.selectFork(sourceFork);
    vm.startPrank(alice);

    vm.expectRevert('Ownable: caller is not the owner');
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    vm.stopPrank();
  }

  function test_success() external {
    vm.selectFork(sourceFork);

    vm.expectEmit(true, true, false, false, address(sourceBridge));
    emit DestinationUpdated(destinationChainSelector, address(destinationBridge));
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    vm.stopPrank();
  }
}
