// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {AaveCctpBridge} from "src/bridges/cctp/AaveCctpBridge.sol";
import {IAaveCctpBridge} from "src/bridges/cctp/interfaces/IAaveCctpBridge.sol";
import {CctpConstants} from "src/bridges/cctp/CctpConstants.sol";

contract AaveCctpBridgeForkTest is Test, CctpConstants {
    using SafeERC20 for IERC20;

    AaveCctpBridge public bridge;
    IERC20 public usdc;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public receiver = makeAddr("receiver");

    uint256 public constant AMOUNT = 10_000e6; // 10k USDC

    function setUp() public {
        string memory rpcUrl = vm.envOr("RPC_MAINNET", string(""));
        vm.createSelectFork(rpcUrl);

        usdc = IERC20(ETHEREUM_USDC);

        bridge = new AaveCctpBridge(
            ETHEREUM_TOKEN_MESSENGER,
            ETHEREUM_USDC,
            ETHEREUM_DOMAIN,
            owner
        );
    }

    function _bridgeTo(
        uint32 destinationDomain,
        uint256 maxFee,
        IAaveCctpBridge.TransferSpeed speed
    ) internal {
        deal(address(usdc), owner, AMOUNT);

        vm.startPrank(owner);
        usdc.approve(address(bridge), AMOUNT);
        bridge.bridge(destinationDomain, AMOUNT, receiver, maxFee, speed);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have no USDC left");
        assertEq(usdc.balanceOf(owner), 0, "Owner should have no USDC left");
    }

    function test_bridge_fast() public {
        _bridgeTo(ARBITRUM_DOMAIN, AMOUNT / 100, IAaveCctpBridge.TransferSpeed.Fast);
    }

    function test_bridge_standard() public {
        _bridgeTo(ARBITRUM_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_avalanche() public {
        _bridgeTo(AVALANCHE_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_optimism() public {
        _bridgeTo(OPTIMISM_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_base() public {
        _bridgeTo(BASE_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_polygon() public {
        _bridgeTo(POLYGON_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_solana() public {
        _bridgeTo(SOLANA_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_unichain() public {
        _bridgeTo(UNICHAIN_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

    function test_bridge_to_linea() public {
        _bridgeTo(LINEA_DOMAIN, 0, IAaveCctpBridge.TransferSpeed.Standard);
    }

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
}
