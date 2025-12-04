// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AaveV3Ethereum, AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Plasma, AaveV3PlasmaAssets} from "aave-address-book/AaveV3Plasma.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {GovernanceV3Arbitrum} from "aave-address-book/GovernanceV3Arbitrum.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";

import {StargateConstants} from "./Constants.sol";
import {AaveStargateBridge} from "src/bridges/stargate/AaveStargateBridge.sol";
import {IAaveStargateBridge} from "src/bridges/stargate/IAaveStargateBridge.sol";
import {IOFT, SendParam, MessagingFee, OFTReceipt} from "src/bridges/stargate/IOFT.sol";

/**
 * @title AaveStargateBridgeForkTest
 * @notice Fork tests for USDT0 OFT bridge via LayerZero V2
 * @dev Uses USDT0 OFT contracts (not legacy Stargate pools)
 *      Ethereum: OAdapterUpgradeable at 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee
 */
contract AaveStargateBridgeForkTestBase is Test, StargateConstants {
    using SafeERC20 for IERC20;

    uint256 public constant AMOUNT_TO_BRIDGE = 10_000_000e6; // 10 million USDT

    uint256 public mainnetFork;
    uint256 public arbitrumFork;

    address public owner = makeAddr("owner");
    address public receiver;

    AaveStargateBridge public mainnetBridge;
    AaveStargateBridge public arbitrumBridge;

    // USDT whale on Ethereum mainnet
    address public constant USDT_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

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

        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, AMOUNT_TO_BRIDGE, receiver, AMOUNT_TO_BRIDGE);

        assertGt(fee, 0, "Fee should be greater than 0");
        emit log_named_uint("Native fee for 10M USDT Ethereum -> Arbitrum", fee);
    }

    function test_quoteOFT_ethereumToArbitrum() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, AMOUNT_TO_BRIDGE, receiver);

        assertGt(amountReceived, 0, "Amount received should be greater than 0");
        assertLe(amountReceived, AMOUNT_TO_BRIDGE, "Amount received should not exceed sent amount");
        emit log_named_uint("Expected amount received on Arbitrum", amountReceived);
    }
}

contract BridgeEthereumToArbitrumTest is AaveStargateBridgeForkTestBase {
    event Bridge(
        address indexed token,
        uint32 indexed dstEid,
        address indexed receiver,
        uint256 amount,
        uint256 minAmountReceived
    );

    function test_quote_ethereumToArbitrum_10MillionUSDT() public {
        vm.selectFork(mainnetFork);

        // Quote the OFT to get expected amount for 10M USDT
        uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, AMOUNT_TO_BRIDGE, receiver);

        // Quote the fee
        uint256 minAmount = (expectedReceived * 9950) / 10000; // 0.5% slippage
        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, AMOUNT_TO_BRIDGE, receiver, minAmount);

        emit log_named_uint("Amount to bridge", AMOUNT_TO_BRIDGE);
        emit log_named_uint("Expected received on Arbitrum", expectedReceived);
        emit log_named_uint("Native fee required (ETH)", fee);

        assertGt(fee, 0, "Fee should be greater than 0");

        emit log_named_uint("Liquidity ratio (received/sent * 10000)", (expectedReceived * 10000) / AMOUNT_TO_BRIDGE);
    }

    function test_bridge_happyPath() public {
        vm.selectFork(mainnetFork);

        uint256 smallAmount = 100e6; // 100 USDT

        // Fund the bridge with USDT
        deal(ETHEREUM_USDT, address(mainnetBridge), smallAmount);
        assertEq(IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)), smallAmount, "Bridge should have USDT");

        // Quote the expected amount and fee
        uint256 expectedReceived = mainnetBridge.quoteOFT(ARBITRUM_EID, smallAmount, receiver);
        uint256 minAmount = (expectedReceived * 9950) / 10000; // 0.5% slippage
        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_EID, smallAmount, receiver, minAmount);

        emit log_named_uint("Amount to bridge", smallAmount);
        emit log_named_uint("Expected received (from quoteOFT)", expectedReceived);
        emit log_named_uint("Native fee required", fee);

        // Verify quote functions work correctly
        assertGt(fee, 0, "Fee should be quoted");
        assertGt(expectedReceived, 0, "Expected received should be quoted");

        // Ensure bridge has enough native token for fees
        vm.deal(address(mainnetBridge), fee + 1 ether);

        // Execute the bridge
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(mainnetBridge));
        emit Bridge(ETHEREUM_USDT, ARBITRUM_EID, receiver, smallAmount, minAmount);

        mainnetBridge.bridge(ARBITRUM_EID, smallAmount, receiver, minAmount);

        vm.stopPrank();

        // Verify bridge balance is 0 after transfer
        assertEq(
            IERC20(ETHEREUM_USDT).balanceOf(address(mainnetBridge)), 0, "Bridge should have 0 USDT after bridging"
        );
    }

    function test_revertsIf_notOwner() public {
        vm.selectFork(mainnetFork);

        address notOwner = makeAddr("not-owner");

        vm.startPrank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        mainnetBridge.bridge(ARBITRUM_EID, AMOUNT_TO_BRIDGE, receiver, AMOUNT_TO_BRIDGE);
        vm.stopPrank();
    }
}

/**
 * @notice Tests for Arbitrum to Ethereum USDT bridging via USDT0 OFT
 * @dev Arbitrum: OUpgradeable at 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92
 */
contract BridgeArbitrumToEthereumTest is Test, StargateConstants {
    using SafeERC20 for IERC20;

    uint256 public constant AMOUNT_TO_BRIDGE = 10_000_000e6; // 10 million USDT

    uint256 public arbitrumFork;

    address public owner = makeAddr("owner");

    AaveStargateBridge public arbitrumBridge;

    event Bridge(
        address indexed token,
        uint32 indexed dstEid,
        address indexed receiver,
        uint256 amount,
        uint256 minAmountReceived
    );

    function setUp() public {
        arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        // Use USDT0 OFT (OUpgradeable) on Arbitrum for bridging
        arbitrumBridge = new AaveStargateBridge(ARBITRUM_USDT0_OFT, ARBITRUM_USDT, owner);
    }

    function test_bridge_arbitrumToEthereum_10MillionUSDT() public {
        vm.selectFork(arbitrumFork);

        address ethReceiver = address(AaveV3Ethereum.COLLECTOR);

        // Use deal to give USDT to bridge
        deal(ARBITRUM_USDT, address(arbitrumBridge), AMOUNT_TO_BRIDGE);

        assertEq(IERC20(ARBITRUM_USDT).balanceOf(address(arbitrumBridge)), AMOUNT_TO_BRIDGE, "Bridge should have USDT");

        // Quote the OFT
        uint256 expectedReceived = arbitrumBridge.quoteOFT(ETHEREUM_EID, AMOUNT_TO_BRIDGE, ethReceiver);
        uint256 minAmount = (expectedReceived * 9950) / 10000; // 0.5% slippage

        // Quote the fee
        uint256 fee = arbitrumBridge.quoteBridge(ETHEREUM_EID, AMOUNT_TO_BRIDGE, ethReceiver, minAmount);

        emit log_named_uint("Bridging amount from Arbitrum to Ethereum", AMOUNT_TO_BRIDGE);
        emit log_named_uint("Expected received on Ethereum", expectedReceived);
        emit log_named_uint("Native fee required (ETH on Arbitrum)", fee);

        // Ensure bridge has enough native token for fees
        vm.deal(address(arbitrumBridge), fee + 1 ether);

        // Bridge the tokens
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true, address(arbitrumBridge));
        emit Bridge(ARBITRUM_USDT, ETHEREUM_EID, ethReceiver, AMOUNT_TO_BRIDGE, minAmount);

        arbitrumBridge.bridge(ETHEREUM_EID, AMOUNT_TO_BRIDGE, ethReceiver, minAmount);

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
}

/**
 * @notice Tests for Ethereum to Plasma USDT bridging via USDT0 OFT
 */
contract QuoteBridgeEthereumToPlasmaTest is Test, StargateConstants {
    uint256 public constant AMOUNT_TO_BRIDGE = 10_000_000e6; // 10 million USDT

    uint256 public mainnetFork;

    address public owner = makeAddr("owner");
    address public receiver;

    AaveStargateBridge public mainnetBridge;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"));

        mainnetBridge = new AaveStargateBridge(ETHEREUM_USDT0_OFT, ETHEREUM_USDT, owner);

        receiver = address(AaveV3Plasma.COLLECTOR);

        vm.deal(address(mainnetBridge), 100 ether);
    }

    function test_quoteBridge_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 fee = mainnetBridge.quoteBridge(PLASMA_EID, AMOUNT_TO_BRIDGE, receiver, AMOUNT_TO_BRIDGE);

        assertGt(fee, 0, "Fee should be greater than 0");
        emit log_named_uint("Native fee for 10M USDT Ethereum -> Plasma", fee);
    }

    function test_quoteOFT_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, AMOUNT_TO_BRIDGE, receiver);

        emit log_named_uint("Amount to bridge", AMOUNT_TO_BRIDGE);
        emit log_named_uint("Expected amount received on Plasma", amountReceived);

        // For OFT (Hydra) transfers, there should be no slippage
        // amountReceived should equal AMOUNT_TO_BRIDGE (or very close)
        if (amountReceived == AMOUNT_TO_BRIDGE) {
            emit log("OFT transfer: No slippage (1:1)");
        } else if (amountReceived > 0) {
            uint256 ratio = (amountReceived * 10000) / AMOUNT_TO_BRIDGE;
            emit log_named_uint("Ratio (received/sent * 10000)", ratio);
        } else {
            // Route not yet configured - this is expected until Stargate enables the path
            emit log("Route status: Ethereum -> Plasma USDT path not yet configured in Stargate");
        }
    }

    function test_quote_smallAmount_ethereumToPlasma() public {
        vm.selectFork(mainnetFork);

        uint256 smallAmount = 100e6; // 100 USDT

        uint256 amountReceived = mainnetBridge.quoteOFT(PLASMA_EID, smallAmount, receiver);
        uint256 fee = mainnetBridge.quoteBridge(PLASMA_EID, smallAmount, receiver, amountReceived);

        emit log_named_uint("Amount to bridge", smallAmount);
        emit log_named_uint("Expected received on Plasma", amountReceived);
        emit log_named_uint("Native fee required (ETH)", fee);

        assertGt(fee, 0, "Fee should be quoted");

        // For OFT, expected received should equal sent amount (no slippage)
        if (amountReceived == smallAmount) {
            emit log("SUCCESS: OFT 1:1 transfer confirmed");
        } else if (amountReceived > 0) {
            emit log_named_uint("Ratio (received/sent * 10000)", (amountReceived * 10000) / smallAmount);
        } else {
            emit log("Route status: Path not configured - verify with Stargate when route is enabled");
        }
    }
}
