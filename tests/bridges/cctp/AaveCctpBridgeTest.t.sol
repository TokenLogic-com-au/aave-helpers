// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";

import {AaveCctpBridge} from "src/bridges/cctp/AaveCctpBridge.sol";
import {IAaveCctpBridge} from "src/bridges/cctp/interfaces/IAaveCctpBridge.sol";
import {MockMessageTransmitterV2} from "./mocks/MockMessageTransmitterV2.sol";
import {MockTokenMessengerV2} from "./mocks/MockTokenMessengerV2.sol";
import {CctpConstants} from "src/bridges/cctp/CctpConstants.sol";

contract AaveCctpBridgeTestBase is Test {
    uint256 public constant AMOUNT = 1_000e6; // 1000 USDC
    uint256 public constant MAX_FEE = 10e6; // 1% of 1000 USDC

    MockTokenMessengerV2 public mockTokenMessenger;
    IERC20 public usdc;
    address public owner = makeAddr("owner");
    address public guardian = makeAddr("guardian");
    address public alice = makeAddr("alice");
    address public receiver = makeAddr("receiver");

    AaveCctpBridge public bridge;

    event Bridge(
        address indexed token,
        uint32 indexed destinationDomain,
        bytes32 indexed receiver,
        uint256 amount,
        IAaveCctpBridge.TransferSpeed speed
    );

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _startOwnerAndApprove(uint256 amount) internal {
        deal(address(usdc), owner, amount);
        vm.startPrank(owner);
        usdc.approve(address(bridge), amount);
    }

    function _assertDeposit(
        uint64 nonce,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) internal view {
        MockTokenMessengerV2.DepositRecord memory deposit = mockTokenMessenger.getDeposit(nonce);
        assertEq(deposit.amount, amount);
        assertEq(deposit.destinationDomain, destinationDomain);
        assertEq(deposit.mintRecipient, mintRecipient);
        assertEq(deposit.burnToken, address(usdc));
        assertEq(deposit.destinationCaller, bytes32(0));
        assertEq(deposit.maxFee, maxFee);
        assertEq(deposit.minFinalityThreshold, minFinalityThreshold);
    }

    function setUp() public {
        ERC20Mock mockUsdc = new ERC20Mock();
        usdc = IERC20(address(mockUsdc));

        MockMessageTransmitterV2 mockMessageTransmitter = new MockMessageTransmitterV2(CctpConstants.ETHEREUM_DOMAIN);
        mockTokenMessenger = new MockTokenMessengerV2(address(mockMessageTransmitter));

        bridge = new AaveCctpBridge(address(mockTokenMessenger), address(usdc), owner, guardian);

        // Set up collectors for different domains
        vm.startPrank(owner);
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, receiver);
        bridge.setDestinationCollector(CctpConstants.BASE_DOMAIN, receiver);
        bridge.setDestinationCollector(CctpConstants.OPTIMISM_DOMAIN, receiver);
        bridge.setDestinationCollector(CctpConstants.AVALANCHE_DOMAIN, receiver);
        vm.stopPrank();
    }
}

contract ConstructorTest is AaveCctpBridgeTestBase {
    function test_revertsIf_zeroTokenMessenger() public {
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        new AaveCctpBridge(address(0), address(usdc), owner, guardian);
    }

    function test_revertsIf_zeroUsdc() public {
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        new AaveCctpBridge(address(mockTokenMessenger), address(0), owner, guardian);
    }

    function test_revertsIf_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new AaveCctpBridge(address(mockTokenMessenger), address(usdc), address(0), guardian);
    }

    function test_successful() public view {
        assertEq(bridge.TOKEN_MESSENGER(), address(mockTokenMessenger));
        assertEq(bridge.USDC(), address(usdc));
        assertEq(bridge.LOCAL_DOMAIN(), CctpConstants.ETHEREUM_DOMAIN);
        assertEq(bridge.owner(), owner);
        assertEq(bridge.guardian(), guardian);
    }
}

contract BridgeTest is AaveCctpBridgeTestBase {
    function test_revertsIf_callerNotOwnerOrGuardian() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice));
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
        vm.expectRevert(abi.encodeWithSelector(IAaveCctpBridge.CollectorNotConfigured.selector, unconfiguredDomain));
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

    function test_successful_fastTransfer() public {
        _startOwnerAndApprove(AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), AMOUNT, IAaveCctpBridge.TransferSpeed.Fast);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 1000, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have no USDC left");
        assertEq(usdc.balanceOf(address(mockTokenMessenger)), AMOUNT, "TokenMessenger should have USDC");

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), 1000, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_successful_standardTransfer() public {
        _startOwnerAndApprove(AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), AMOUNT, IAaveCctpBridge.TransferSpeed.Standard);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Standard);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), 0, CctpConstants.STANDARD_FINALITY_THRESHOLD);
    }

    function test_successful_guardianCanBridge() public {
        deal(address(usdc), guardian, AMOUNT);

        vm.startPrank(guardian);
        usdc.approve(address(bridge), AMOUNT);

        vm.expectEmit(true, true, true, true, address(bridge));
        emit Bridge(address(usdc), CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), AMOUNT, IAaveCctpBridge.TransferSpeed.Fast);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 1000, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have no USDC left");
    }

    function test_fuzz_successful(uint256 amount, uint32 dstDomain) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(dstDomain != CctpConstants.ETHEREUM_DOMAIN && dstDomain > 0);

        deal(address(usdc), owner, amount);

        vm.startPrank(owner);
        bridge.setDestinationCollector(dstDomain, receiver);
        usdc.approve(address(bridge), amount);

        bridge.bridge(dstDomain, amount, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0);
        assertEq(usdc.balanceOf(owner), 0);
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
        assertEq(bridge.LOCAL_DOMAIN(), CctpConstants.ETHEREUM_DOMAIN);
    }

    function test_whoCanRescue() public view {
        assertEq(bridge.whoCanRescue(), owner);
    }

    function test_maxRescue() public view {
        assertEq(bridge.maxRescue(address(usdc)), type(uint256).max);
    }

    function test_finalityThresholds() public view {
        assertEq(bridge.FAST(), 1000);
        assertEq(bridge.STANDARD(), 2000);
    }

    function test_getDestinationCollector() public view {
        assertEq(bridge.getDestinationCollector(CctpConstants.ARBITRUM_DOMAIN), _addressToBytes32(receiver));
        assertEq(bridge.getDestinationCollector(CctpConstants.BASE_DOMAIN), _addressToBytes32(receiver));
    }
}

contract SetDestinationCollectorTest is AaveCctpBridgeTestBase {
    event CollectorSet(uint32 indexed destinationDomain, bytes32 indexed collector);

    function test_revertsIf_callerNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_guardianTriesToSet() public {
        vm.startPrank(guardian);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, guardian));
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, receiver);
        vm.stopPrank();
    }

    function test_revertsIf_zeroCollector() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, address(0));
        vm.stopPrank();
    }

    function test_revertsIf_zeroCollectorNonEVM() public {
        vm.startPrank(owner);
        vm.expectRevert(IAaveCctpBridge.InvalidZeroAddress.selector);
        bridge.setDestinationCollectorNonEVM(CctpConstants.SOLANA_DOMAIN, bytes32(0));
        vm.stopPrank();
    }

    function test_successful() public {
        address newCollector = makeAddr("newCollector");

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CollectorSet(CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(newCollector));

        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, newCollector);
        vm.stopPrank();

        assertEq(bridge.getDestinationCollector(CctpConstants.ARBITRUM_DOMAIN), _addressToBytes32(newCollector));
    }

    function test_setDestinationCollectorNonEVM_successful() public {
        bytes32 newCollector = keccak256("collector");

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CollectorSet(CctpConstants.SOLANA_DOMAIN, newCollector);

        bridge.setDestinationCollectorNonEVM(CctpConstants.SOLANA_DOMAIN, newCollector);
        vm.stopPrank();

        assertEq(bridge.getDestinationCollector(CctpConstants.ARBITRUM_DOMAIN), newCollector);
    }

    function test_canUpdateExisting() public {
        address newCollector = makeAddr("newCollector");

        vm.startPrank(owner);
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, newCollector);
        vm.stopPrank();

        assertEq(bridge.getDestinationCollector(CctpConstants.ARBITRUM_DOMAIN), _addressToBytes32(newCollector));
    }
}

contract MultipleBridgesTest is AaveCctpBridgeTestBase {
    function test_multipleBridges_incrementNonce() public {
        deal(address(usdc), owner, AMOUNT * 3);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT * 3);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, AMOUNT - 1, IAaveCctpBridge.TransferSpeed.Fast);
        bridge.bridge(CctpConstants.BASE_DOMAIN, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Standard);
        bridge.bridge(CctpConstants.OPTIMISM_DOMAIN, AMOUNT, 500, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        // Verify each deposit went to correct domain
        assertEq(mockTokenMessenger.getDeposit(1).destinationDomain, CctpConstants.ARBITRUM_DOMAIN);
        assertEq(mockTokenMessenger.getDeposit(2).destinationDomain, CctpConstants.BASE_DOMAIN);
        assertEq(mockTokenMessenger.getDeposit(3).destinationDomain, CctpConstants.OPTIMISM_DOMAIN);
    }
}

contract MintRecipientEncodingTest is AaveCctpBridgeTestBase {
    function test_addressEncodedCorrectly() public {
        _startOwnerAndApprove(AMOUNT);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_fuzz_addressEncodedCorrectly(address recipient) public {
        vm.assume(recipient != address(0));

        _startOwnerAndApprove(AMOUNT);

        vm.startPrank(owner);
        bridge.setDestinationCollector(CctpConstants.ARBITRUM_DOMAIN, recipient);
        vm.stopPrank();

        _startOwnerAndApprove(AMOUNT);
        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(recipient), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
    }
}

contract DepositRecordVerificationTest is AaveCctpBridgeTestBase {
    function test_bridge_fastTransfer_verifiesAllDepositFields() public {
        _startOwnerAndApprove(AMOUNT);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 500, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), 500, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_bridge_standardTransfer_verifiesAllDepositFields() public {
        _startOwnerAndApprove(AMOUNT);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, 0, IAaveCctpBridge.TransferSpeed.Standard);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), 0, CctpConstants.STANDARD_FINALITY_THRESHOLD);
    }

    function test_bridge_withDifferentDomains() public {
        deal(address(usdc), owner, AMOUNT * 4);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT * 4);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        bridge.bridge(CctpConstants.BASE_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        bridge.bridge(CctpConstants.OPTIMISM_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        bridge.bridge(CctpConstants.AVALANCHE_DOMAIN, AMOUNT, MAX_FEE, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
        _assertDeposit(2, AMOUNT, CctpConstants.BASE_DOMAIN, _addressToBytes32(receiver), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
        _assertDeposit(3, AMOUNT, CctpConstants.OPTIMISM_DOMAIN, _addressToBytes32(receiver), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
        _assertDeposit(4, AMOUNT, CctpConstants.AVALANCHE_DOMAIN, _addressToBytes32(receiver), MAX_FEE, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_bridge_withMinimumAmount() public {
        uint256 minAmount = 1;
        deal(address(usdc), owner, minAmount);

        vm.startPrank(owner);
        usdc.approve(address(bridge), minAmount);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, minAmount, 0, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, minAmount, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), 0, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_bridge_withLargeAmount() public {
        uint256 largeAmount = 1_000_000_000e6; // 1 billion USDC
        uint256 largeFee = largeAmount / 100; // 1% fee
        deal(address(usdc), owner, largeAmount);

        vm.startPrank(owner);
        usdc.approve(address(bridge), largeAmount);

        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, largeAmount, largeFee, IAaveCctpBridge.TransferSpeed.Fast);
        vm.stopPrank();

        _assertDeposit(1, largeAmount, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), largeFee, CctpConstants.FAST_FINALITY_THRESHOLD);
    }

    function test_bridge_maxFeePassedCorrectly() public {
        _startOwnerAndApprove(AMOUNT);

        uint256 customMaxFee = 12345;
        bridge.bridge(CctpConstants.ARBITRUM_DOMAIN, AMOUNT, customMaxFee, IAaveCctpBridge.TransferSpeed.Standard);
        vm.stopPrank();

        _assertDeposit(1, AMOUNT, CctpConstants.ARBITRUM_DOMAIN, _addressToBytes32(receiver), customMaxFee, CctpConstants.STANDARD_FINALITY_THRESHOLD);
    }
}
