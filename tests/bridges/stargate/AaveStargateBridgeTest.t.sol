// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";

import {AaveStargateBridge} from "src/bridges/stargate/AaveStargateBridge.sol";
import {IAaveStargateBridge} from "src/bridges/stargate/IAaveStargateBridge.sol";
import {MockStargate} from "./mocks/MockStargate.sol";

contract AaveStargateBridgeTestBase is Test {
    uint32 public constant ARBITRUM_EID = 30110;
    uint32 public constant OPTIMISM_EID = 30111;
    uint256 public constant MOCK_FEE = 0.01 ether;
    uint256 public constant AMOUNT = 1_000e6;

    MockStargate public mockStargate;
    IERC20 public usdt;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public receiver = makeAddr("receiver");

    AaveStargateBridge bridge;

    event Bridge(
        address indexed token,
        uint32 indexed dstEid,
        address indexed receiver,
        uint256 amount,
        uint256 minAmountReceived
    );

    function setUp() public {
        ERC20Mock mockUsdt = new ERC20Mock();
        usdt = IERC20(address(mockUsdt));

        mockStargate = new MockStargate(address(usdt));

        bridge = new AaveStargateBridge(address(mockStargate), address(usdt), owner);

        vm.deal(address(bridge), 10 ether);
    }
}

contract BridgeTest is AaveStargateBridgeTestBase {
    function test_revertsIf_callerNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.bridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT);
        vm.stopPrank();
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveStargateBridge.InvalidZeroAmount.selector);
        bridge.bridge(ARBITRUM_EID, 0, receiver, 0);
        vm.stopPrank();
    }

    function test_successful() public {
        deal(address(usdt), address(bridge), AMOUNT);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdt), ARBITRUM_EID, receiver, AMOUNT, AMOUNT);

        bridge.bridge(ARBITRUM_EID, AMOUNT, receiver, AMOUNT);

        vm.stopPrank();

        assertEq(usdt.balanceOf(address(bridge)), 0, "Bridge should have no USDT left");
        assertEq(usdt.balanceOf(address(mockStargate)), AMOUNT, "MockStargate should have USDT");
    }

    function test_successful_withSlippage() public {
        uint256 minAmount = AMOUNT - (AMOUNT * 50) / 10000; // 0.5% slippage
        deal(address(usdt), address(bridge), AMOUNT);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdt), ARBITRUM_EID, receiver, AMOUNT, minAmount);

        bridge.bridge(ARBITRUM_EID, AMOUNT, receiver, minAmount);

        vm.stopPrank();
    }

    function test_successful_fuzz(uint256 amount, uint32 dstEid) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(dstEid > 0);

        deal(address(usdt), address(bridge), amount);

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdt), dstEid, receiver, amount, amount);

        bridge.bridge(dstEid, amount, receiver, amount);

        vm.stopPrank();

        assertEq(usdt.balanceOf(address(bridge)), 0);
    }
}

contract QuoteBridgeTest is AaveStargateBridgeTestBase {
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

contract QuoteOFTTest is AaveStargateBridgeTestBase {
    function test_successful() public view {
        uint256 amountReceived = bridge.quoteOFT(ARBITRUM_EID, AMOUNT, receiver);
        assertEq(amountReceived, AMOUNT);
    }

    function test_successful_withFee() public {
        uint256 expectedReceived = AMOUNT - (AMOUNT * 10) / 10000; // 0.1% fee
        mockStargate.setMockAmountReceived(expectedReceived);

        uint256 amountReceived = bridge.quoteOFT(ARBITRUM_EID, AMOUNT, receiver);
        assertEq(amountReceived, expectedReceived);
    }
}

contract TransferOwnershipTest is AaveStargateBridgeTestBase {
    function test_revertsIf_invalidCaller() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.transferOwnership(makeAddr("new-admin"));
        vm.stopPrank();
    }

    function test_successful() public {
        address newOwner = makeAddr("new-owner");

        vm.startPrank(owner);
        bridge.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(bridge.owner(), newOwner);
    }
}

contract EmergencyTokenTransferTest is AaveStargateBridgeTestBase {
    function test_revertsIf_invalidCaller() public {
        vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
        vm.startPrank(alice);
        bridge.emergencyTokenTransfer(address(usdt), alice, AMOUNT);
        vm.stopPrank();
    }

    function test_successful() public {
        deal(address(usdt), address(bridge), AMOUNT);

        assertEq(usdt.balanceOf(address(bridge)), AMOUNT);

        address collector = makeAddr("collector");
        uint256 initialBalance = usdt.balanceOf(collector);

        vm.startPrank(owner);
        bridge.emergencyTokenTransfer(address(usdt), collector, AMOUNT);
        vm.stopPrank();

        assertEq(usdt.balanceOf(collector), initialBalance + AMOUNT);
        assertEq(usdt.balanceOf(address(bridge)), 0);
    }
}

contract ReceiveEtherTest is AaveStargateBridgeTestBase {
    function test_successful_receiveEther() public {
        uint256 initialBalance = address(bridge).balance;
        uint256 amount = 1 ether;

        (bool ok,) = address(bridge).call{value: amount}("");

        assertTrue(ok);
        assertEq(address(bridge).balance, initialBalance + amount);
    }
}

contract ViewFunctionsTest is AaveStargateBridgeTestBase {
    function test_stargateUsdt() public view {
        assertEq(bridge.STARGATE_USDT(), address(mockStargate));
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
