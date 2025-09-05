// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {ERC20Mock} from 'openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol';
import {Strings} from 'aave-v3-origin/contracts/dependencies/openzeppelin/contracts/Strings.sol';

import {Constants} from 'tests/bridges/ccip/Constants.sol';
import {CCIPReceiver} from 'src/dependencies/chainlink/CCIPReceiver.sol';
import {MockCCIPRouter, Client, IRouterClient} from 'tests/bridges/ccip/mocks/MockRouter.sol';
import {AaveGhoCcipBridge} from 'src/bridges/ccip/AaveGhoCcipBridge.sol';
import {IAaveGhoCcipBridge} from 'src/bridges/ccip/interfaces/IAaveGhoCcipBridge.sol';

contract AaveGhoCcipBridgeTestBase is Test, Constants {
  uint256 public constant mockFee = 0.01 ether;
  uint256 public constant amount = 1_000 ether;
  uint256 public constant gasLimit = 0; // use default gasLimit

  IRouterClient public ccipRouter;
  IERC20 public gho;
  address public collector = makeAddr('collector');
  address public admin = makeAddr('admin');
  address public alice = makeAddr('alice');
  address public destinationBridge = makeAddr('destination-bridge');

  AaveGhoCcipBridge bridge;

  function setUp() public {
    MockCCIPRouter mockRouter = new MockCCIPRouter();
    ccipRouter = IRouterClient(address(mockRouter));
    mockRouter.setFee(mockFee);

    ERC20Mock mockGho = new ERC20Mock();
    gho = IERC20(address(mockGho));

    bridge = new AaveGhoCcipBridge(address(mockRouter), address(mockGho), collector, admin);

    vm.prank(alice);
    gho.approve(address(bridge), type(uint256).max);
  }

  /// Builds dummy message for test
  function _buildDummyMessage() internal pure returns (Client.Any2EVMMessage memory message) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
    return
      Client.Any2EVMMessage({
        messageId: bytes32(0),
        sourceChainSelector: MAINNET_CHAIN_SELECTOR,
        sender: abi.encode(address(0)),
        data: '',
        destTokenAmounts: tokenAmounts
      });
  }

  function _buildInvalidMessage() internal returns (Client.Any2EVMMessage memory) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: address(gho), amount: amount});

    Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
      messageId: bytes32(0),
      sourceChainSelector: MAINNET_CHAIN_SELECTOR,
      sender: abi.encode(address(1)),
      data: '',
      destTokenAmounts: tokenAmounts
    });

    vm.startPrank(bridge.ROUTER());
    bridge.ccipReceive(message);
    vm.stopPrank();

    return message;
  }
}

contract SetDestinationBridgeTest is AaveGhoCcipBridgeTestBase {
  function test_revertsIf_callerNotAdmin() external {
    vm.startPrank(alice);
    vm.expectRevert('Ownable: caller is not the owner');
    bridge.setDestinationChain(
      ARBITRUM_CHAIN_SELECTOR,
      abi.encodePacked(destinationBridge),
      bytes(''),
      200_000
    );
  }

  function test_successful() external {
    vm.startPrank(admin);
    vm.expectEmit(address(bridge));
    emit IAaveGhoCcipBridge.DestinationChainSet(
      MAINNET_CHAIN_SELECTOR,
      abi.encodePacked(destinationBridge),
      200_000
    );
    bridge.setDestinationChain(
      ARBITRUM_CHAIN_SELECTOR,
      abi.encodePacked(destinationBridge),
      bytes(''),
      200_000
    );

    (bytes memory dest, , ) = bridge.destinations(ARBITRUM_CHAIN_SELECTOR);

    assertEq(
      dest,
      abi.encodePacked(destinationBridge),
      'Destination bridge not set correctly in the mapping'
    );
  }
}

contract RemoveDestinationBridgeTest is AaveGhoCcipBridgeTestBase {
  function test_revertsIf_callerNotAdmin() external {
    vm.startPrank(alice);
    vm.expectRevert('Ownable: caller is not the owner');
    bridge.removeDestinationChain(MAINNET_CHAIN_SELECTOR);
  }

  function test_successful() external {
    vm.startPrank(admin);
    vm.expectEmit(address(bridge));
    emit IAaveGhoCcipBridge.DestinationChainSet(
      MAINNET_CHAIN_SELECTOR,
      abi.encodePacked(destinationBridge),
      200_000
    );
    bridge.setDestinationChain(
      ARBITRUM_CHAIN_SELECTOR,
      abi.encodePacked(destinationBridge),
      bytes(''),
      200_000
    );

    (bytes memory dest, , ) = bridge.destinations(ARBITRUM_CHAIN_SELECTOR);

    assertEq(
      dest,
      abi.encodePacked(destinationBridge),
      'Destination bridge not set correctly in the mapping'
    );

    vm.expectEmit(address(bridge));
    emit IAaveGhoCcipBridge.DestinationChainSet(MAINNET_CHAIN_SELECTOR, bytes(''), 0);
    bridge.removeDestinationChain(MAINNET_CHAIN_SELECTOR);

    (dest, , ) = bridge.destinations(ARBITRUM_CHAIN_SELECTOR);

    assertEq(dest, bytes(''), 'Destination bridge not set correctly in the mapping');
  }
}

contract ProcessMessageTest is AaveGhoCcipBridgeTestBase {
  function test_revertsIf_callerNotSelf() public {
    vm.startPrank(admin);
    vm.expectRevert(IAaveGhoCcipBridge.OnlySelf.selector);
    bridge.processMessage(_buildDummyMessage());
  }
}

contract CcipReceiveTest is AaveGhoCcipBridgeTestBase {
  function test_revertsIf_callerNotRouter() public {
    vm.startPrank(admin);
    vm.expectRevert(abi.encodeWithSelector(CCIPReceiver.InvalidRouter.selector, admin));
    bridge.ccipReceive(_buildDummyMessage());
  }

  function test_successful_receivedInvalidMessage() public {
    vm.startPrank(bridge.ROUTER());
    vm.expectEmit(address(bridge));
    emit IAaveGhoCcipBridge.BridgeMessageFailed(bytes32(0), PANIC_SELECTOR);
    bridge.ccipReceive(_buildDummyMessage());
  }

  function test_successful() public {
    // Fund bridge with GHO
    deal(address(gho), address(bridge), amount);
    vm.startPrank(bridge.ROUTER());

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: address(gho), amount: amount});

    Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
      messageId: bytes32(0),
      sourceChainSelector: MAINNET_CHAIN_SELECTOR,
      sender: abi.encode(address(0)),
      data: '',
      destTokenAmounts: tokenAmounts
    });

    vm.expectEmit(true, true, false, true, address(bridge));
    emit IAaveGhoCcipBridge.BridgeMessageFinalized(bytes32(0), collector, amount);
    bridge.ccipReceive(message);

    vm.stopPrank();
  }
}

contract HandleInvalidMessageTest is AaveGhoCcipBridgeTestBase {
  address public feeToken = address(gho);

  function test_revertIf_callerNotOwner() external {
    vm.startPrank(alice);
    vm.expectRevert('Ownable: caller is not the owner');
    bridge.recoverFailedMessageTokens(bytes32(0));
  }

  function test_revertIf_MessageNotFound() external {
    vm.startPrank(admin);
    vm.expectRevert(
      abi.encodeWithSelector(IAaveGhoCcipBridge.MessageNotFound.selector, bytes32('1'))
    );
    bridge.recoverFailedMessageTokens(bytes32('1'));
  }

  function test_success() external {
    // Fund bridge with GHO
    deal(address(gho), address(bridge), amount);

    Client.Any2EVMMessage memory message = _buildInvalidMessage();

    vm.startPrank(admin);
    uint256 balanceBefore = gho.balanceOf(collector);

    vm.expectEmit(true, false, false, false, address(bridge));
    emit IAaveGhoCcipBridge.BridgeMessageRecovered(message.messageId);
    bridge.recoverFailedMessageTokens(message.messageId);

    uint256 balanceAfter = gho.balanceOf(collector);

    assertEq(balanceAfter, balanceBefore + amount);
  }
}
