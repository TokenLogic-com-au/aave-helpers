// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";
import {Strings} from "aave-v3-origin/contracts/dependencies/openzeppelin/contracts/Strings.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AaveV3Ethereum, AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from "aave-address-book/AaveV3Arbitrum.sol";

import {CCIPLocalSimulatorFork, Register, Internal} from "./mocks/CCIPLocalSimulatorFork.sol";
import {Constants} from "./Constants.sol";
import {Client} from "src/bridges/ccip/libraries/Client.sol";
import {CCIPReceiver} from "src/bridges/ccip/CCIPReceiver.sol";
import {IRouterClient} from "src/bridges/ccip/interfaces/IRouterClient.sol";
import {AaveGhoCcipBridge} from "src/bridges/ccip/AaveGhoCcipBridge.sol";
import {IAaveGhoCcipBridge} from "src/bridges/ccip/interfaces/IAaveGhoCcipBridge.sol";

contract AaveGhoCcipBridgeForkTestBase is Test, Constants {
    uint256 public constant AMOUNT_TO_SEND = 1_000_000 ether;
    uint256 public mainnetFork;
    uint256 public arbitrumFork;
    address public admin = makeAddr("admin");
    address public facilitator = makeAddr("facilitator");

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    AaveGhoCcipBridge mainnetBridge;
    AaveGhoCcipBridge arbitrumBridge;

    function setUp() public {
        mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), 22637440);
        arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"), 344116880);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails memory arbitrumNetworkDetails = Register.NetworkDetails({
            chainSelector: ARBITRUM_CHAIN_SELECTOR,
            routerAddress: ARBITRUM_ROUTER,
            linkAddress: ARBITRUM_LINK,
            wrappedNativeAddress: ARBITRUM_WETH,
            ccipBnMAddress: 0xA189971a2c5AcA0DFC5Ee7a2C44a2Ae27b3CF389,
            ccipLnMAddress: 0x30DeCD269277b8094c00B0bacC3aCaF3fF4Da7fB,
            rmnProxyAddress: ARBITRUM_RMN_PROXY,
            registryModuleOwnerCustomAddress: ARBITRUM_REGISTRY_OWNER,
            tokenAdminRegistryAddress: ARBITRUM_TOKEN_ADMIN
        });
        ccipLocalSimulatorFork.setNetworkDetails(block.chainid, arbitrumNetworkDetails);

        arbitrumBridge = new AaveGhoCcipBridge(
            arbitrumNetworkDetails.routerAddress,
            AaveV3ArbitrumAssets.GHO_UNDERLYING,
            address(AaveV3Arbitrum.COLLECTOR),
            admin
        );

        vm.startPrank(facilitator);
        IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).approve(address(arbitrumBridge), type(uint256).max);
        vm.stopPrank();

        vm.selectFork(mainnetFork);
        Register.NetworkDetails memory mainnetDetails = Register.NetworkDetails({
            chainSelector: MAINNET_CHAIN_SELECTOR,
            routerAddress: MAINNET_ROUTER,
            linkAddress: MAINNET_LINK,
            wrappedNativeAddress: MAINNET_WETH,
            ccipBnMAddress: 0xA189971a2c5AcA0DFC5Ee7a2C44a2Ae27b3CF389,
            ccipLnMAddress: 0x30DeCD269277b8094c00B0bacC3aCaF3fF4Da7fB,
            rmnProxyAddress: MAINNET_RMN_PROXY,
            registryModuleOwnerCustomAddress: MAINNET_REGISTRY_OWNER,
            tokenAdminRegistryAddress: MAINNET_TOKEN_ADMIN
        });
        ccipLocalSimulatorFork.setNetworkDetails(block.chainid, mainnetDetails);

        mainnetBridge = new AaveGhoCcipBridge(
            mainnetDetails.routerAddress, AaveV3EthereumAssets.GHO_UNDERLYING, address(AaveV3Ethereum.COLLECTOR), admin
        );

        vm.startPrank(admin);
        mainnetBridge.setDestinationChain(ARBITRUM_CHAIN_SELECTOR, address(arbitrumBridge));
        mainnetBridge.grantRole(mainnetBridge.BRIDGER_ROLE(), facilitator);
        vm.stopPrank();

        vm.startPrank(facilitator);
        IERC20(AaveV3EthereumAssets.GHO_UNDERLYING).approve(address(mainnetBridge), type(uint256).max);
        vm.stopPrank();

        vm.selectFork(arbitrumFork);
        vm.startPrank(admin);
        arbitrumBridge.setDestinationChain(MAINNET_CHAIN_SELECTOR, address(mainnetBridge));
        arbitrumBridge.grantRole(arbitrumBridge.BRIDGER_ROLE(), facilitator);
        vm.stopPrank();
    }

    function _getMessageFromRecordedLogs() internal returns (Internal.EVM2EVMMessage memory) {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Internal.EVM2EVMMessage memory message;
        uint256 length = entries.length;
        for (uint256 i; i < length; ++i) {
            if (entries[i].topics[0] == CCIPLocalSimulatorFork.CCIPSendRequested.selector) {
                message = abi.decode(entries[i].data, (Internal.EVM2EVMMessage));
            }
        }

        // Emit event again because getRecordedLogs clears logs after call
        emit CCIPLocalSimulatorFork.CCIPSendRequested(message);

        return message;
    }

    function _buildInvalidMessage() internal returns (Internal.EVM2EVMMessage memory) {
        vm.startPrank(admin);
        vm.selectFork(mainnetFork);
        mainnetBridge.setDestinationChain(ARBITRUM_CHAIN_SELECTOR, address(arbitrumBridge));
        mainnetBridge.grantRole(mainnetBridge.BRIDGER_ROLE(), facilitator);
        vm.stopPrank();

        uint256 fee =
            mainnetBridge.quoteBridge(ARBITRUM_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, AaveV3EthereumAssets.GHO_UNDERLYING);
        deal(AaveV3EthereumAssets.GHO_UNDERLYING, facilitator, AMOUNT_TO_SEND + fee);

        vm.startPrank(facilitator);
        mainnetBridge.send(ARBITRUM_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, AaveV3EthereumAssets.GHO_UNDERLYING);
        vm.stopPrank();

        Internal.EVM2EVMMessage memory message = _getMessageFromRecordedLogs();
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);

        return message;
    }

    function assertMessage(
        Internal.EVM2EVMMessage memory internalMessage,
        Client.EVMTokenAmount[] memory invalidTokenTransfers
    ) internal pure {
        for (uint256 i = 0; i < internalMessage.tokenAmounts.length; ++i) {
            assertEq(internalMessage.tokenAmounts[i].amount, invalidTokenTransfers[i].amount);
        }
    }
}

contract SendMainnetToArbitrum is AaveGhoCcipBridgeForkTestBase {
    address public feeToken = AaveV3EthereumAssets.GHO_UNDERLYING;

    function test_revertsIf_unsupportedChain() external {
        vm.selectFork(mainnetFork);
        vm.startPrank(facilitator);
        vm.expectRevert(IAaveGhoCcipBridge.UnsupportedChain.selector);
        mainnetBridge.send(BLAST_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, feeToken);
    }

    function test_revertsIf_callerNoBridgerRole() external {
        vm.selectFork(mainnetFork);
        address caller = makeAddr('random-caller');
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(caller), 20),
                " is missing role ",
                Strings.toHexString(uint256(mainnetBridge.BRIDGER_ROLE()), 32)
            )
        );
        mainnetBridge.send(ARBITRUM_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, feeToken);
    }

    function test_revertsIf_invalidTransferAmount() external {
        vm.selectFork(mainnetFork);
        vm.startPrank(facilitator);
        vm.expectRevert(IAaveGhoCcipBridge.InvalidZeroAmount.selector);
        mainnetBridge.send(ARBITRUM_CHAIN_SELECTOR, 0, 0, feeToken);
    }

    function test_revertsIf_sourceChainNotConfigured() external {
        vm.startPrank(admin);
        vm.selectFork(arbitrumFork);
        arbitrumBridge.removeDestinationChain(MAINNET_CHAIN_SELECTOR);
        vm.stopPrank();

        vm.selectFork(mainnetFork);
        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, feeToken);
        deal(AaveV3EthereumAssets.GHO_UNDERLYING, facilitator, AMOUNT_TO_SEND + fee);

        vm.startPrank(facilitator);
        vm.expectEmit(false, true, true, true, address(mainnetBridge));
        emit IAaveGhoCcipBridge.BridgeInitiated(bytes32(0), ARBITRUM_CHAIN_SELECTOR, facilitator, AMOUNT_TO_SEND);
        mainnetBridge.send(ARBITRUM_CHAIN_SELECTOR, AMOUNT_TO_SEND, 0, feeToken);

        Internal.EVM2EVMMessage memory message = _getMessageFromRecordedLogs();

        vm.expectEmit(true, false, false, false, address(arbitrumBridge));
        emit IAaveGhoCcipBridge.FailedToFinalizeBridge(message.messageId, bytes(hex'5ea23900'));
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);

        Client.EVMTokenAmount[] memory messageData = arbitrumBridge.getInvalidMessage(message.messageId);
        assertTrue(messageData.length > 0);
        Client.EVMTokenAmount[] memory invalidTokenTransfers = arbitrumBridge.getInvalidMessage(message.messageId);
        assertMessage(message, invalidTokenTransfers);
        vm.stopPrank();
    }

    function testFuzz_revertsIf_rateLimitExceeded(uint256 amount) external {
        vm.selectFork(mainnetFork);
        uint128 limit = mainnetBridge.getRateLimit(ARBITRUM_CHAIN_SELECTOR);

        vm.assume(amount > limit && amount < 1e32); // made top limit to prevent arithmetic overflow
        vm.selectFork(mainnetFork);
        uint256 fee = 1 ether; // set static fee because quoteBridge reverts if amount exceed limit
        deal(AaveV3EthereumAssets.GHO_UNDERLYING, facilitator, amount + fee);
        deal(facilitator, 100);

        vm.startPrank(facilitator);
        vm.expectRevert(abi.encodeWithSelector(IAaveGhoCcipBridge.RateLimitExceeded.selector, limit));
        mainnetBridge.send{value: 100}(ARBITRUM_CHAIN_SELECTOR, amount, 0, feeToken);
        vm.stopPrank();
    }

    function test_successful_fuzz(uint256 amount) external {
        vm.selectFork(mainnetFork);
        uint128 limit = mainnetBridge.getRateLimit(ARBITRUM_CHAIN_SELECTOR);

        vm.assume(amount > 0 && amount <= limit);
        vm.selectFork(arbitrumFork);

        uint256 beforeBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(address(AaveV3Arbitrum.COLLECTOR));

        vm.selectFork(mainnetFork);
        uint256 fee = mainnetBridge.quoteBridge(ARBITRUM_CHAIN_SELECTOR, amount, 0, feeToken);
        deal(AaveV3EthereumAssets.GHO_UNDERLYING, facilitator, amount + fee);

        vm.startPrank(facilitator);
        vm.expectEmit(false, true, true, true, address(mainnetBridge));
        emit IAaveGhoCcipBridge.BridgeInitiated(bytes32(0), ARBITRUM_CHAIN_SELECTOR, facilitator, amount);
        mainnetBridge.send(ARBITRUM_CHAIN_SELECTOR, amount, 0, feeToken);

        Internal.EVM2EVMMessage memory message = _getMessageFromRecordedLogs();

        vm.expectEmit(true, true, false, true, address(arbitrumBridge));
        emit IAaveGhoCcipBridge.BridgeFinalized(message.messageId, address(AaveV3Arbitrum.COLLECTOR), amount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumFork);
        uint256 afterBalance = IERC20(AaveV3ArbitrumAssets.GHO_UNDERLYING).balanceOf(address(AaveV3Arbitrum.COLLECTOR));
        assertEq(afterBalance, beforeBalance + amount, "Bridged amount not updated correctly");
        vm.stopPrank();
    }
}
