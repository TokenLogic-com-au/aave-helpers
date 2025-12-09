// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";

import {AaveCctpBridge} from "src/bridges/cctp/AaveCctpBridge.sol";
import {IAaveCctpBridge} from "src/bridges/cctp/interfaces/IAaveCctpBridge.sol";
import {MockTokenMessengerV2} from "./mocks/MockTokenMessengerV2.sol";
import {CctpConstants} from "./Constants.sol";

contract AaveCctpBridgeTestBase is Test, CctpConstants {
    uint256 public constant AMOUNT = 1_000e6; // 1000 USDC
    uint256 public constant MOCK_FEE = 100; // 0.01% fee in basis points

    MockTokenMessengerV2 public mockTokenMessenger;
    IERC20 public usdc;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public receiver = makeAddr("receiver");

    AaveCctpBridge public bridge;

    event Bridge(
        address indexed token,
        uint32 indexed destinationDomain,
        address indexed receiver,
        uint256 amount,
        uint64 nonce,
        IAaveCctpBridge.TransferSpeed speed
    );

    function setUp() public {
        ERC20Mock mockUsdc = new ERC20Mock();
        usdc = IERC20(address(mockUsdc));

        mockTokenMessenger = new MockTokenMessengerV2(makeAddr("messageTransmitter"));
        mockTokenMessenger.setMockMinFee(MOCK_FEE);

        bridge = new AaveCctpBridge(
            address(mockTokenMessenger),
            address(usdc),
            ETHEREUM_DOMAIN,
            owner
        );
    }
}

contract ConstructorTest is AaveCctpBridgeTestBase {
    function test_revertsIf_zeroTokenMessenger() public {
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        new AaveCctpBridge(address(0), address(usdc), ETHEREUM_DOMAIN, owner);
    }

    function test_revertsIf_zeroUsdc() public {
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        new AaveCctpBridge(address(mockTokenMessenger), address(0), ETHEREUM_DOMAIN, owner);
    }

    function test_revertsIf_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new AaveCctpBridge(address(mockTokenMessenger), address(usdc), ETHEREUM_DOMAIN, address(0));
    }

    function test_successful() public view {
        assertEq(bridge.TOKEN_MESSENGER(), address(mockTokenMessenger));
        assertEq(bridge.USDC(), address(usdc));
        assertEq(bridge.LOCAL_DOMAIN(), ETHEREUM_DOMAIN);
        assertEq(bridge.owner(), owner);
    }
}

contract BridgeTest is AaveCctpBridgeTestBase {
    function test_revertsIf_callerNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.bridge(ARBITRUM_DOMAIN, AMOUNT, receiver, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAmount.selector);
        bridge.bridge(ARBITRUM_DOMAIN, 0, receiver, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();
    }

    function test_revertsIf_zeroReceiver() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidReceiver.selector);
        bridge.bridge(ARBITRUM_DOMAIN, AMOUNT, address(0), 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();
    }

    function test_revertsIf_sameDestinationDomain() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidDestinationDomain.selector);
        bridge.bridge(ETHEREUM_DOMAIN, AMOUNT, receiver, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();
    }

    function test_successful_fastTransfer() public {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), ARBITRUM_DOMAIN, receiver, AMOUNT, 1, IAaveCctpBridge.TransferSpeed.Fast);

        uint64 nonce = bridge.bridge(ARBITRUM_DOMAIN, AMOUNT, receiver, 1000, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(nonce, 1, "Nonce should be 1");
        assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have no USDC left");
        assertEq(usdc.balanceOf(address(mockTokenMessenger)), AMOUNT, "TokenMessenger should have USDC");

        // Verify deposit record
        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);
        assertEq(deposit.amount, AMOUNT);
        assertEq(deposit.destinationDomain, ARBITRUM_DOMAIN);
        assertEq(deposit.minFinalityThreshold, FAST_FINALITY_THRESHOLD);
    }

    function test_successful_standardTransfer() public {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), ARBITRUM_DOMAIN, receiver, AMOUNT, 1, IAaveCctpBridge.TransferSpeed.Standard);

        uint64 nonce = bridge.bridge(ARBITRUM_DOMAIN, AMOUNT, receiver, 0, IAaveCctpBridge.TransferSpeed.Standard);
        vm.stopPrank();

        // Verify deposit record has standard finality threshold
        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);
        assertEq(deposit.minFinalityThreshold, STANDARD_FINALITY_THRESHOLD);
    }

    function test_successful_fuzz(uint256 amount, uint32 dstDomain) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(dstDomain != ETHEREUM_DOMAIN && dstDomain > 0);

        deal(address(usdc), owner, amount);

        vm.startPrank(owner);
        usdc.approve(address(bridge), amount);

        bridge.bridge(dstDomain, amount, receiver, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0);
    }
}

contract BridgeFastTest is AaveCctpBridgeTestBase {
    function test_revertsIf_callerNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAmount.selector);
        bridge.bridgeFast(ARBITRUM_DOMAIN, 0, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_zeroReceiver() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidReceiver.selector);
        bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, address(0));
        vm.stopPrank();
    }

    function test_successful() public {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), ARBITRUM_DOMAIN, receiver, AMOUNT, 1, IAaveCctpBridge.TransferSpeed.Fast);

        uint64 nonce = bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, receiver);
        vm.stopPrank();

        assertEq(nonce, 1);

        // Verify max fee is set to type(uint256).max
        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);
        assertEq(deposit.maxFee, type(uint256).max);
        assertEq(deposit.minFinalityThreshold, FAST_FINALITY_THRESHOLD);
    }

    function test_successful_fuzz(uint256 amount, uint32 dstDomain) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(dstDomain != ETHEREUM_DOMAIN && dstDomain > 0);

        deal(address(usdc), owner, amount);

        vm.startPrank(owner);
        usdc.approve(address(bridge), amount);

        bridge.bridgeFast(dstDomain, amount, receiver);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0);
    }
}

contract BridgeStandardTest is AaveCctpBridgeTestBase {
    function test_revertsIf_callerNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.bridgeStandard(ARBITRUM_DOMAIN, AMOUNT, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_zeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAmount.selector);
        bridge.bridgeStandard(ARBITRUM_DOMAIN, 0, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_zeroReceiver() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidReceiver.selector);
        bridge.bridgeStandard(ARBITRUM_DOMAIN, AMOUNT, address(0));
        vm.stopPrank();
    }

    function test_successful() public {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), ARBITRUM_DOMAIN, receiver, AMOUNT, 1, IAaveCctpBridge.TransferSpeed.Standard);

        uint64 nonce = bridge.bridgeStandard(ARBITRUM_DOMAIN, AMOUNT, receiver);
        vm.stopPrank();

        assertEq(nonce, 1);

        // Verify maxFee is 0 and finality threshold is standard
        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);
        assertEq(deposit.maxFee, 0);
        assertEq(deposit.minFinalityThreshold, STANDARD_FINALITY_THRESHOLD);
    }

    function test_successful_fuzz(uint256 amount, uint32 dstDomain) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(dstDomain != ETHEREUM_DOMAIN && dstDomain > 0);

        deal(address(usdc), owner, amount);

        vm.startPrank(owner);
        usdc.approve(address(bridge), amount);

        bridge.bridgeStandard(dstDomain, amount, receiver);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0);
    }
}

contract QuoteFeeTest is AaveCctpBridgeTestBase {
    function test_successful() public view {
        uint256 fee = bridge.quoteFee(ARBITRUM_DOMAIN, AMOUNT);
        assertEq(fee, MOCK_FEE);
    }

    function test_successful_fuzz(uint256 amount, uint32 dstDomain) public view {
        vm.assume(amount > 0);
        vm.assume(dstDomain > 0);

        uint256 fee = bridge.quoteFee(dstDomain, amount);
        assertEq(fee, MOCK_FEE);
    }
}

contract TransferOwnershipTest is AaveCctpBridgeTestBase {
    function test_revertsIf_invalidCaller() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.transferOwnership(makeAddr("new-owner"));
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

contract EmergencyTokenTransferTest is AaveCctpBridgeTestBase {
    function test_revertsIf_invalidCaller() public {
        vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
        vm.startPrank(alice);
        bridge.emergencyTokenTransfer(address(usdc), alice, AMOUNT);
        vm.stopPrank();
    }

    function test_successful() public {
        deal(address(usdc), address(bridge), AMOUNT);

        assertEq(usdc.balanceOf(address(bridge)), AMOUNT);

        address collector = makeAddr("collector");
        uint256 initialBalance = usdc.balanceOf(collector);

        vm.startPrank(owner);
        bridge.emergencyTokenTransfer(address(usdc), collector, AMOUNT);
        vm.stopPrank();

        assertEq(usdc.balanceOf(collector), initialBalance + AMOUNT);
        assertEq(usdc.balanceOf(address(bridge)), 0);
    }
}

contract ViewFunctionsTest is AaveCctpBridgeTestBase {
    function test_tokenMessenger() public view {
        assertEq(bridge.TOKEN_MESSENGER(), address(mockTokenMessenger));
    }

    function test_usdc() public view {
        assertEq(bridge.USDC(), address(usdc));
    }

    function test_localDomain() public view {
        assertEq(bridge.LOCAL_DOMAIN(), ETHEREUM_DOMAIN);
    }

    function test_whoCanRescue() public view {
        assertEq(bridge.whoCanRescue(), owner);
    }

    function test_maxRescue() public view {
        assertEq(bridge.maxRescue(address(usdc)), type(uint256).max);
    }

    function test_finalityThresholds() public view {
        assertEq(bridge.FAST_FINALITY_THRESHOLD(), 1000);
        assertEq(bridge.STANDARD_FINALITY_THRESHOLD(), 2000);
    }
}

contract MultipleBridgesTest is AaveCctpBridgeTestBase {
    function test_multipleBridges_incrementNonce() public {
        deal(address(usdc), owner, AMOUNT * 3);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT * 3);

        uint64 nonce1 = bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, receiver);
        uint64 nonce2 = bridge.bridgeStandard(BASE_DOMAIN, AMOUNT, receiver);
        uint64 nonce3 = bridge.bridge(OPTIMISM_DOMAIN, AMOUNT, receiver, 500, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(nonce1, 1);
        assertEq(nonce2, 2);
        assertEq(nonce3, 3);

        // Verify each deposit went to correct domain
        assertEq(mockTokenMessenger.getDeposit(1).destinationDomain, ARBITRUM_DOMAIN);
        assertEq(mockTokenMessenger.getDeposit(2).destinationDomain, BASE_DOMAIN);
        assertEq(mockTokenMessenger.getDeposit(3).destinationDomain, OPTIMISM_DOMAIN);
    }
}

contract MintRecipientEncodingTest is AaveCctpBridgeTestBase {
    function test_addressEncodedCorrectly() public {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        uint64 nonce = bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, receiver);
        vm.stopPrank();

        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);

        // Verify the mintRecipient is correctly encoded as bytes32
        bytes32 expectedRecipient = bytes32(uint256(uint160(receiver)));
        assertEq(deposit.mintRecipient, expectedRecipient);
    }

    function test_addressEncodedCorrectly_fuzz(address recipient) public {
        vm.assume(recipient != address(0));

        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);

        uint64 nonce = bridge.bridgeFast(ARBITRUM_DOMAIN, AMOUNT, recipient);
        vm.stopPrank();

        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);

        bytes32 expectedRecipient = bytes32(uint256(uint160(recipient)));
        assertEq(deposit.mintRecipient, expectedRecipient);
    }
}
