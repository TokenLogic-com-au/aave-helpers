// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Arbitrum} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Plasma} from "aave-address-book/AaveV3Plasma.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";

import {StargateConstants} from "./Constants.sol";
import {AaveStargateBridge} from "src/bridges/stargate/AaveStargateBridge.sol";
import {IAaveStargateBridge} from "src/bridges/stargate/interfaces/IAaveStargateBridge.sol";

/**
 * @title AaveStargateBridgeForkTest
 * @notice Fork tests for USDT0 OFT bridge via LayerZero V2
 */
contract AaveStargateBridgeForkTestBase is Test, StargateConstants {
    using SafeERC20 for IERC20;

    uint256 public constant LARGE_BRIDGE_AMOUNT = 10_000_000e6; // 10 million USDT
    uint256 public constant BRIDGE_AMOUNT = 1000e6; // 1000 USDT

    uint256 public mainnetFork;
    uint256 public arbitrumFork;

    address public owner = makeAddr("owner");
    address public receiver;

    AaveStargateBridge public mainnetBridge;
    AaveStargateBridge public arbitrumBridge;

    event Bridge(
        address indexed token,
        uint32 indexed dstEid,
        address indexed receiver,
        uint256 amount,
        uint256 minAmountReceived
    );

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"));

        // Use USDT0 OFT (OAdapterUpgradeable) on Ethereum for bridging
        mainnetBridge = new AaveStargateBridge(ETHEREUM_USDT0_OFT, ETHEREUM_USDT, owner);

        receiver = address(AaveV3Arbitrum.COLLECTOR);

        vm.deal(address(mainnetBridge), 100 ether);
    }
}

contract QuoteBridgeEthereumToArbitrumTest is AaveStargateBridgeForkTestBase {
    function test_quoteBridge_ethereumToArbitrum() public {
        vm.selectFork(mainnetFork);

        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be greater than 0");
    }

    function test_quoteOFT_ethereumToArbitrum() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver);

        assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");
    }

    function test_quote_ethereumToArbitrum_10MillionUSDT() public {
        vm.selectFork(mainnetFork);

        // Quote the OFT to get expected amount for 10M USDT
        uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver);

        assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");

        // Quote the fee
        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be greater than 0");
    }
}

contract BridgeEthereumToArbitrumTest is AaveStargateBridgeForkTestBase {
    function test_bridge_happyPath() public {
        vm.selectFork(mainnetFork);

        // Fund the owner with USDT
        deal(ETHEREUM_USDT, owner, BRIDGE_AMOUNT);
        assertEq(IERC20(ETHEREUM_USDT).balanceOf(owner), BRIDGE_AMOUNT, "Owner should have USDT");

        // Quote the expected amount and fee
        uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, BRIDGE_AMOUNT, receiver);

        assertEq(expectedReceived, BRIDGE_AMOUNT, "OFT should have no slippage");

        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

        // Verify quote functions work correctly
        assertGt(fee, 0, "Fee should be quoted");

        // Ensure bridge has enough native token for fees
        vm.deal(address(mainnetBridge), fee + 1 ether);

        // Execute the bridge
        vm.startPrank(owner);

        SafeERC20.forceApprove(IERC20(ETHEREUM_USDT), address(mainnetBridge), BRIDGE_AMOUNT);

        vm.expectEmit(true, true, true, true, address(mainnetBridge));
        emit Bridge(ETHEREUM_USDT, ARBITRUM_EID, receiver, BRIDGE_AMOUNT, BRIDGE_AMOUNT);

        mainnetBridge.bridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

        vm.stopPrank();

        // Verify bridge balance is 0 after transfer
        assertEq(
            IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)), 0, "Bridge should have 0 USDT after bridging"
        );

        // Verify user balance is 0 after bridging
        assertEq(
            IERC20(ETHEREUM_USDT).balanceOf(owner), 0, "User should have no USDT left on ETH after bridging"
        );
    }

    function test_revertsIf_notOwner() public {
        vm.selectFork(mainnetFork);

        address notOwner = makeAddr("not-owner");

        vm.startPrank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        mainnetBridge.bridge(ARBITRUM_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);
        vm.stopPrank();
    }

    function test_bridge_withMsgValue() public {
        vm.selectFork(mainnetFork);

        address deployer = makeAddr("bridge-deployer");
        vm.prank(deployer);
        AaveStargateBridge unfundedBridge = new AaveStargateBridge(ETHEREUM_USDT0_OFT, ETHEREUM_USDT, owner);
        assertEq(address(unfundedBridge).balance, 0, "Bridge should not be pre-funded");

        deal(ETHEREUM_USDT, owner, BRIDGE_AMOUNT);

        // Quote the fee
        uint256 fee = unfundedBridge.quoteBridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

        // Give owner enough ETH to pay the fee
        vm.deal(owner, fee);

        vm.startPrank(owner);
        SafeERC20.forceApprove(IERC20(ETHEREUM_USDT), address(unfundedBridge), BRIDGE_AMOUNT);

        vm.expectEmit(true, true, true, true, address(unfundedBridge));
        emit Bridge(ETHEREUM_USDT, ARBITRUM_EID, receiver, BRIDGE_AMOUNT, BRIDGE_AMOUNT);

        // Send ETH fee as msg.value instead of pre-funding the bridge
        unfundedBridge.bridge{value: fee}(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

        vm.stopPrank();

        assertEq(
            IERC20(ETHEREUM_USDT).balanceOf(address(unfundedBridge)), 0, "Bridge should have 0 USDT after bridging"
        );
        assertEq(address(unfundedBridge).balance, 0, "Bridge should not have ETH after bridging");
        assertEq(IERC20(ETHEREUM_USDT).balanceOf(owner), 0, "User should have no USDT left after bridging");
    }


    function test_bridge_withExactAmount() public {
        vm.selectFork(mainnetFork);
        deal(ETHEREUM_USDT, owner, BRIDGE_AMOUNT);

        uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, BRIDGE_AMOUNT, receiver);

        assertEq(expectedReceived, BRIDGE_AMOUNT, "OFT should have no slippage");

        vm.startPrank(owner);
        SafeERC20.forceApprove(IERC20(ETHEREUM_USDT), address(mainnetBridge), BRIDGE_AMOUNT);
        // Bridge with exact amount (OFT guarantees 1:1)
        mainnetBridge.bridge(ARBITRUM_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);
        vm.stopPrank();

        assertEq(IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)), 0, "Bridge should have 0 USDT");
    }

    function test_revertsIf_zeroAmount() public {
        vm.selectFork(mainnetFork);

        vm.prank(owner);
        vm.expectRevert(IAaveStargateBridge.InvalidZeroAmount.selector);
        mainnetBridge.bridge(ARBITRUM_EID, 0, receiver, 0);
    }
}

/**
 * @notice Tests for Arbitrum to Ethereum USDT bridging via USDT0 OFT
 * @dev Arbitrum: OUpgradeable at 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92
 */
contract BridgeArbitrumToEthereumTest is AaveStargateBridgeForkTestBase {
    function setUp() public override {
        arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        owner = makeAddr("owner");
        arbitrumBridge = new AaveStargateBridge(ARBITRUM_USDT0_OFT, ARBITRUM_USDT, owner);
    }

    function test_bridge_arbitrumToEthereum_10MillionUSDT() public {
        vm.selectFork(arbitrumFork);

        address ethReceiver = address(AaveV3Ethereum.COLLECTOR);

        deal(ARBITRUM_USDT, owner, LARGE_BRIDGE_AMOUNT);

        assertEq(IERC20(ARBITRUM_USDT).balanceOf(owner), LARGE_BRIDGE_AMOUNT, "Owner should have USDT");

        // Quote the OFT
        uint256 expectedReceived = arbitrumBridge.quoteOFT(ETHEREUM_EID, LARGE_BRIDGE_AMOUNT, ethReceiver);

        assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");

        // Quote the fee
        uint256 fee = arbitrumBridge.quoteBridge(ETHEREUM_EID, LARGE_BRIDGE_AMOUNT, ethReceiver, LARGE_BRIDGE_AMOUNT);

        // Ensure bridge has enough native token for fees
        vm.deal(address(arbitrumBridge), fee + 1 ether);

        // Bridge the tokens
        vm.startPrank(owner);

        IERC20(ARBITRUM_USDT).approve(address(arbitrumBridge), LARGE_BRIDGE_AMOUNT);

        vm.expectEmit(true, true, true, true, address(arbitrumBridge));
        emit Bridge(ARBITRUM_USDT, ETHEREUM_EID, ethReceiver, LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT);

        arbitrumBridge.bridge(ETHEREUM_EID, LARGE_BRIDGE_AMOUNT, ethReceiver, LARGE_BRIDGE_AMOUNT);

        vm.stopPrank();

        // Verify bridge balance is 0 after transfer
        assertEq(
            IERC20(ARBITRUM_USDT).balanceOf(address(arbitrumBridge)), 0, "Bridge should have 0 USDT after bridging"
        );
    }
}

contract EmergencyTokenTransferTest is AaveStargateBridgeForkTestBase {
    function test_emergencyTokenTransfer() public {
        vm.selectFork(mainnetFork);

        uint256 amount = 1_000_000e6; // 1 million USDT

        // Use deal to give USDT to bridge
        deal(ETHEREUM_USDT, address(mainnetBridge), amount);

        uint256 collectorBalanceBefore = IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR));

        vm.prank(owner);
        mainnetBridge.emergencyTokenTransfer(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), amount);

        assertEq(
            IERC20(ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
            collectorBalanceBefore + amount,
            "Collector should receive tokens"
        );

        assertEq(IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)), 0, "Bridge should have 0 balance");
    }
}

contract TransferOwnershipTest is AaveStargateBridgeForkTestBase {
    function test_transferOwnership() public {
        vm.selectFork(mainnetFork);

        address newOwner = GovernanceV3Ethereum.EXECUTOR_LVL_1;

        vm.prank(owner);
        mainnetBridge.transferOwnership(newOwner);

        assertEq(mainnetBridge.owner(), newOwner, "Ownership should be transferred");
    }

    function test_transferOwnership_revertsIf_notOwner() public {
        vm.selectFork(mainnetFork);

        address notOwner = makeAddr("not-owner");
        address newOwner = makeAddr("new-owner");

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        mainnetBridge.transferOwnership(newOwner);
    }

    function test_renounceOwnership() public {
        vm.selectFork(mainnetFork);

        vm.prank(owner);
        mainnetBridge.renounceOwnership();

        assertEq(mainnetBridge.owner(), address(0), "Owner should be zero address");
    }
}

/**
 * @notice Tests for Ethereum to Plasma USDT bridging via USDT0 OFT
 */
contract QuoteBridgeEthereumToPlasmaTest is AaveStargateBridgeForkTestBase {
    function setUp() public override {
        super.setUp();
        receiver = address(AaveV3Plasma.COLLECTOR);
    }

    function test_quoteBridge_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 fee = mainnetBridge.quoteBridge(PLASMA_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be greater than 0");
    }

    function test_quoteOFT_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, LARGE_BRIDGE_AMOUNT, receiver);
        assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");
    }

    function test_quote_BRIDGE_AMOUNT_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, BRIDGE_AMOUNT, receiver);
        uint256 fee = mainnetBridge.quoteBridge(PLASMA_EID, BRIDGE_AMOUNT, receiver, BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be quoted");
        assertEq(amountReceived, BRIDGE_AMOUNT, "OFT should have no slippage");
    }
}

/**
 * @notice Tests for constructor and immutable values
 */
contract ConstructorAndImmutablesTest is AaveStargateBridgeForkTestBase {
    function test_constructor_setsImmutables() public {
        vm.selectFork(mainnetFork);

        assertEq(mainnetBridge.OFT_USDT(), ETHEREUM_USDT0_OFT, "OFT_USDT should be set correctly");
        assertEq(mainnetBridge.USDT(), ETHEREUM_USDT, "USDT should be set correctly");
        assertEq(mainnetBridge.owner(), owner, "Owner should be set correctly");
    }

    function test_constructor_arbitrumBridge() public {
        arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        vm.selectFork(arbitrumFork);

        arbitrumBridge = new AaveStargateBridge(ARBITRUM_USDT0_OFT, ARBITRUM_USDT, owner);

        assertEq(arbitrumBridge.OFT_USDT(), ARBITRUM_USDT0_OFT, "OFT_USDT should be set correctly");
        assertEq(arbitrumBridge.USDT(), ARBITRUM_USDT, "USDT should be set correctly");
        assertEq(arbitrumBridge.owner(), owner, "Owner should be set correctly");
    }
}

/**
 * @notice Tests for receive function and native token handling
 */
contract ReceiveFunctionTest is AaveStargateBridgeForkTestBase {
    function test_receive_acceptsNativeTokens() public {
        vm.selectFork(mainnetFork);

        uint256 balanceBefore = address(mainnetBridge).balance;

        address sender = makeAddr("sender");
        vm.deal(sender, 10 ether);

        vm.prank(sender);
        (bool success,) = address(mainnetBridge).call{value: 1 ether}("");

        assertTrue(success, "Should accept native tokens");
        assertEq(address(mainnetBridge).balance, balanceBefore + 1 ether, "Balance should increase");
    }
}

/**
 * @notice Tests for Rescuable functionality
 */
contract RescuableTest is AaveStargateBridgeForkTestBase {
    function test_whoCanRescue_returnsOwner() public {
        vm.selectFork(mainnetFork);

        assertEq(mainnetBridge.whoCanRescue(), owner, "whoCanRescue should return owner");
    }

    function test_maxRescue_returnsMaxUint() public {
        vm.selectFork(mainnetFork);

        assertEq(mainnetBridge.maxRescue(ETHEREUM_USDT), type(uint256).max, "maxRescue should return max uint256");
        assertEq(mainnetBridge.maxRescue(address(0)), type(uint256).max, "maxRescue should return max uint256 for any address");
    }

    function test_emergencyTokenTransfer_revertsIf_notOwner() public {
        vm.selectFork(mainnetFork);

        address notOwner = makeAddr("not-owner");
        uint256 amount = 1_000e6;

        deal(ETHEREUM_USDT, address(mainnetBridge), amount);

        vm.prank(notOwner);
        vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
        mainnetBridge.emergencyTokenTransfer(ETHEREUM_USDT, address(AaveV3Ethereum.COLLECTOR), amount);
    }

    function test_emergencyEtherTransfer() public {
        vm.selectFork(mainnetFork);

        uint256 ethAmount = 5 ether;
        vm.deal(address(mainnetBridge), ethAmount);

        address rescueTo = address(AaveV3Ethereum.COLLECTOR);
        uint256 collectorBalanceBefore = rescueTo.balance;

        vm.prank(owner);
        IRescuable(address(mainnetBridge)).emergencyEtherTransfer(rescueTo, ethAmount);

        assertEq(rescueTo.balance, collectorBalanceBefore + ethAmount, "Collector should receive ETH");
        assertEq(address(mainnetBridge).balance, 0, "Bridge should have 0 ETH balance");
    }
}

/**
 * @notice Tests for Ethereum to Polygon USDT bridging
 */
contract QuoteBridgeEthereumToPolygonTest is AaveStargateBridgeForkTestBase {
    function setUp() public override {
        super.setUp();
        receiver = makeAddr("polygon-receiver");
    }

    function test_quoteBridge_ethereumToPolygon() public {
        vm.selectFork(mainnetFork);

        uint256 fee = mainnetBridge.quoteBridge(POLYGON_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be greater than 0");
    }

    function test_quoteOFT_ethereumToPolygon() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(POLYGON_EID, LARGE_BRIDGE_AMOUNT, receiver);

        assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");
    }
}

/**
 * @notice Tests for Ethereum to Optimism USDT bridging
 */
contract QuoteBridgeEthereumToOptimismTest is AaveStargateBridgeForkTestBase {
    function setUp() public override {
        super.setUp();
        receiver = makeAddr("optimism-receiver");
    }

    function test_quoteBridge_ethereumToOptimism() public {
        vm.selectFork(mainnetFork);

        uint256 fee = mainnetBridge.quoteBridge(OPTIMISM_EID, LARGE_BRIDGE_AMOUNT, receiver, LARGE_BRIDGE_AMOUNT);

        assertGt(fee, 0, "Fee should be greater than 0");
    }

    function test_quoteOFT_ethereumToOptimism() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(OPTIMISM_EID, LARGE_BRIDGE_AMOUNT, receiver);
        assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");
    }
}
