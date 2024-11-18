// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from 'forge-std/Test.sol';
import {Strings} from 'aave-v3-origin/contracts/dependencies/openzeppelin/contracts/Strings.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {CCIPLocalSimulatorFork, Register} from '@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

import {AaveCcipGhoBridge, IAaveCcipGhoBridge} from 'src/bridges/chainlink-ccip/AaveCcipGhoBridge.sol';

/// @dev forge test --match-path=tests/bridges/chainlink-ccip/*.sol -vvv
contract AaveCcipGhoBridgeTest is Test {
  CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
  uint256 public sourceFork;
  uint256 public destinationFork;
  address public owner;
  address public alice;
  IRouterClient public sourceRouter;
  uint64 public destinationChainSelector;

  uint256 amountToSend = 1_000e18;
  AaveCcipGhoBridge sourceBridge;
  AaveCcipGhoBridge destinationBridge;

  event TransferIssued(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    address indexed from,
    uint256 totalAmount
  );
  event TransferFinished(bytes32 indexed messageId, address indexed to, uint256 amount);

  event DestinationUpdated(uint64 indexed chainSelector, address indexed bridge);

  function setUp() public {
    destinationFork = vm.createSelectFork(vm.rpcUrl('arbitrum'));
    sourceFork = vm.createFork(vm.rpcUrl('mainnet'));

    owner = makeAddr('owner');
    alice = makeAddr('alice');

    ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
    vm.makePersistent(address(ccipLocalSimulatorFork));

    // arbitrum mainnet register config (https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet#arbitrum-mainnet)
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

    destinationBridge = new AaveCcipGhoBridge(
      destinationNetworkDetails.routerAddress,
      AaveV3ArbitrumAssets.GHO_UNDERLYING,
      address(AaveV3Arbitrum.COLLECTOR),
      owner
    );

    vm.selectFork(sourceFork);
    // mainnet register config (https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet#ethereum-mainnet)
    Register.NetworkDetails memory sourceNetworkDetails = Register.NetworkDetails({
      chainSelector: 5009297550715157269,
      routerAddress: 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
      linkAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
      wrappedNativeAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      ccipBnMAddress: 0xA189971a2c5AcA0DFC5Ee7a2C44a2Ae27b3CF389,
      ccipLnMAddress: 0x30DeCD269277b8094c00B0bacC3aCaF3fF4Da7fB
    });
    ccipLocalSimulatorFork.setNetworkDetails(block.chainid, sourceNetworkDetails);
    sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

    sourceBridge = new AaveCcipGhoBridge(
      sourceNetworkDetails.routerAddress,
      AaveV3EthereumAssets.GHO_UNDERLYING,
      address(AaveV3Ethereum.COLLECTOR),
      owner
    );

    deal(AaveV3EthereumAssets.GHO_UNDERLYING, alice, amountToSend + 1000e18);

    vm.startPrank(alice);
    IERC20(AaveV3EthereumAssets.GHO_UNDERLYING).approve(
      address(sourceBridge),
      amountToSend + 1000e18
    );
    vm.stopPrank();

    vm.selectFork(destinationFork);
    vm.startPrank(owner);
    destinationBridge.setDestinationBridge(
      sourceNetworkDetails.chainSelector,
      address(sourceBridge)
    );

    vm.stopPrank();
  }
}

contract BridgeToken is AaveCcipGhoBridgeTest {
  function test_revertsIf_UnsupportedChain() external {
    vm.selectFork(sourceFork);

    vm.startPrank(alice);
    vm.expectRevert(IAaveCcipGhoBridge.UnsupportedChain.selector);
    sourceBridge.bridge(destinationChainSelector, amountToSend);
  }

  function test_revertsIf_NotBridger() external {
    vm.selectFork(sourceFork);
    vm.prank(owner);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));

    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodePacked(
        'AccessControl: account ',
        Strings.toHexString(uint160(alice), 20),
        ' is missing role ',
        Strings.toHexString(uint256(sourceBridge.BRIDGER_ROLE()), 32)
      )
    );
    sourceBridge.bridge(destinationChainSelector, amountToSend);
  }

  function test_revertsIf_InvalidTransferAmount() external {
    vm.selectFork(sourceFork);
    vm.startPrank(owner);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    sourceBridge.grantRole(sourceBridge.BRIDGER_ROLE(), alice);
    vm.stopPrank();

    vm.startPrank(alice);
    vm.expectRevert(IAaveCcipGhoBridge.InvalidTransferAmount.selector);
    sourceBridge.bridge(destinationChainSelector, 0);
  }

  function test_success() external {
    vm.selectFork(destinationFork);

    uint256 beforeBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(
      address(AaveV3Arbitrum.COLLECTOR)
    );

    vm.selectFork(sourceFork);
    vm.startPrank(owner);
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    sourceBridge.grantRole(sourceBridge.BRIDGER_ROLE(), alice);
    vm.stopPrank();

    vm.startPrank(alice);
    vm.expectEmit(false, true, false, true, address(sourceBridge));
    emit TransferIssued(bytes32(0), destinationChainSelector, alice, amountToSend);
    sourceBridge.bridge(destinationChainSelector, amountToSend);

    vm.expectEmit(false, true, true, true, address(destinationBridge));
    emit TransferFinished(bytes32(0), address(AaveV3Arbitrum.COLLECTOR), amountToSend);
    ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
    uint256 afterBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(
      address(AaveV3Arbitrum.COLLECTOR)
    );
    assertEq(afterBalance, beforeBalance + amountToSend);
    vm.stopPrank();
  }
}

contract SetDestinationBridgeTest is AaveCcipGhoBridgeTest {
  function test_revertIf_NotOwner() external {
    vm.selectFork(sourceFork);
    vm.startPrank(alice);

    vm.expectRevert(
      abi.encodePacked(
        'AccessControl: account ',
        Strings.toHexString(uint160(alice), 20),
        ' is missing role ',
        Strings.toHexString(uint256(sourceBridge.DEFAULT_ADMIN_ROLE()), 32)
      )
    );
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    vm.stopPrank();
  }

  function test_success() external {
    vm.startPrank(owner);
    vm.selectFork(sourceFork);

    vm.expectEmit(true, true, false, false, address(sourceBridge));
    emit DestinationUpdated(destinationChainSelector, address(destinationBridge));
    sourceBridge.setDestinationBridge(destinationChainSelector, address(destinationBridge));
    vm.stopPrank();
  }
}