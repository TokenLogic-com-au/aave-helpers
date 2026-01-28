// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {ERC20Mock} from 'openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IRescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';

import {AaveOFTBridge} from 'src/bridges/oft/AaveOFTBridge.sol';
import {IAaveOFTBridge} from 'src/bridges/oft/interfaces/IAaveOFTBridge.sol';
import {MockOFT} from './mocks/MockOFT.sol';

contract AaveOFTBridgeTestBase is Test {
  uint32 public constant ARBITRUM_EID = 30110;
  uint32 public constant OPTIMISM_EID = 30111;
  uint256 public constant MOCK_FEE = 0.01 ether;
  uint256 public constant AMOUNT = 1_000e6;

  MockOFT public mockOFT;
  IERC20 public usdt;
  address public owner = makeAddr('owner');
  address public alice = makeAddr('alice');
  address public receiver = makeAddr('receiver');
  address public guardian = makeAddr('guardian');

  AaveOFTBridge bridge;

  uint256 public maxFee;

  event Bridge(
    address indexed token,
    uint32 indexed dstEid,
    address indexed receiver,
    uint256 amount,
    uint256 minAmountReceived
  );

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function setUp() public {
    ERC20Mock mockUsdt = new ERC20Mock();
    usdt = IERC20(address(mockUsdt));

    mockOFT = new MockOFT(address(usdt));

    bridge = new AaveOFTBridge(address(mockOFT), owner, guardian);
    maxFee = bridge.quoteBridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT);
    vm.deal(address(bridge), 10 ether);
  }
}

contract ConstructorTest is AaveOFTBridgeTestBase {
  function test_revertsIf_zero_oft_address() public {
    vm.expectRevert(IAaveOFTBridge.InvalidZeroAddress.selector);
    new AaveOFTBridge(address(0), owner, guardian);
  }

  function test_successful() public view {
    assertEq(bridge.OFT_USDT(), address(mockOFT));
    assertEq(bridge.USDT(), address(usdt));
    assertEq(bridge.owner(), owner);
  }
}

contract BridgeTest is AaveOFTBridgeTestBase {
  function test_revertsIf_callerNotOwner() public {
    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice));
    bridge.bridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT, maxFee);
    vm.stopPrank();
  }

  function test_revertsIf_zeroAmount() public {
    vm.startPrank(owner);
    vm.expectRevert(IAaveOFTBridge.InvalidZeroAmount.selector);
    bridge.bridge(ARBITRUM_EID, 0, receiver, 0, maxFee);
    vm.stopPrank();
  }

  function test_successful() public {
    deal(address(usdt), owner, AMOUNT);

    vm.startPrank(owner);

    usdt.approve(address(bridge), AMOUNT);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit Bridge(address(usdt), ARBITRUM_EID, receiver, AMOUNT, AMOUNT);

    bridge.bridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT, maxFee);

    vm.stopPrank();

    assertEq(usdt.balanceOf(address(bridge)), 0, 'Bridge should have no USDT left');
    assertEq(usdt.balanceOf(address(mockOFT)), AMOUNT, 'MockOFT should have USDT');
  }

  function test_successful_fuzz(uint256 amount, uint32 dstEid) public {
    vm.assume(amount > 0 && amount < type(uint128).max);
    vm.assume(dstEid > 0);

    deal(address(usdt), owner, amount);

    vm.startPrank(owner);

    usdt.approve(address(bridge), amount);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit Bridge(address(usdt), dstEid, receiver, amount, amount);

    uint256 fee = bridge.quoteBridge(dstEid, amount, receiver, amount);

    bridge.bridge(dstEid, amount, receiver, amount, fee);

    vm.stopPrank();

    assertEq(usdt.balanceOf(address(bridge)), 0);
  }
}

contract QuoteBridgeTest is AaveOFTBridgeTestBase {
  function test_successful() public view {
    uint256 fee = bridge.quoteBridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT);
    assertEq(fee, MOCK_FEE);
  }

  function test_successful_fuzz(uint256 amount, uint32 dstEid) public view {
    vm.assume(amount > 0);
    vm.assume(dstEid > 0);

    uint256 fee = bridge.quoteBridge(dstEid, amount, receiver, amount);
    assertEq(fee, MOCK_FEE);
  }
}

contract QuoteOFTTest is AaveOFTBridgeTestBase {
  function test_noSlippage() public view {
    uint256 amountReceived = bridge.quoteOFT(ARBITRUM_EID, AMOUNT, receiver);
    assertEq(amountReceived, AMOUNT, 'OFT should have no slippage');
  }

  function test_noSlippage_fuzz(uint256 amount, uint32 dstEid) public view {
    vm.assume(amount > 0);
    vm.assume(dstEid > 0);

    uint256 amountReceived = bridge.quoteOFT(dstEid, amount, receiver);
    assertEq(amountReceived, amount, 'OFT should have no slippage');
  }
}

contract TransferOwnershipTest is AaveOFTBridgeTestBase {
  function test_revertsIf_invalidCaller() public {
    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    bridge.transferOwnership(makeAddr('new-admin'));
    vm.stopPrank();
  }

  function test_successful() public {
    address newOwner = makeAddr('new-owner');

    vm.startPrank(owner);

    vm.expectEmit(true, true, true, true, address(bridge));
    emit OwnershipTransferred(owner, newOwner);

    bridge.transferOwnership(newOwner);

    vm.stopPrank();

    assertEq(bridge.owner(), newOwner);
  }
}

contract EmergencyTokenTransferTest is AaveOFTBridgeTestBase {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
    vm.startPrank(alice);
    bridge.emergencyTokenTransfer(address(usdt), alice, AMOUNT);
    vm.stopPrank();
  }

  function test_successful() public {
    deal(address(usdt), address(bridge), AMOUNT);

    assertEq(usdt.balanceOf(address(bridge)), AMOUNT);

    address collector = makeAddr('collector');
    uint256 initialBalance = usdt.balanceOf(collector);

    vm.startPrank(owner);
    bridge.emergencyTokenTransfer(address(usdt), collector, AMOUNT);
    vm.stopPrank();

    assertEq(usdt.balanceOf(collector), initialBalance + AMOUNT);
    assertEq(usdt.balanceOf(address(bridge)), 0);
  }
}

contract ReceiveEtherTest is AaveOFTBridgeTestBase {
  function test_successful_receiveEther() public {
    uint256 initialBalance = address(bridge).balance;
    uint256 amount = 1 ether;

    (bool ok, ) = address(bridge).call{value: amount}('');

    assertTrue(ok);
    assertEq(address(bridge).balance, initialBalance + amount);
  }
}

contract ViewFunctionsTest is AaveOFTBridgeTestBase {
  function test_oft_usdt() public view {
    assertEq(bridge.OFT_USDT(), address(mockOFT));
  }

  function test_usdt() public view {
    assertEq(bridge.USDT(), address(usdt));
  }

  function test_whoCanRescue() public view {
    assertEq(bridge.whoCanRescue(), owner);
  }

  function test_maxRescue() public view {
    assertEq(bridge.maxRescue(address(usdt)), type(uint256).max);
  }
}
