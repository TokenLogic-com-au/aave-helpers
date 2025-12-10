// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Rescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {IAaveCctpBridge} from "./interfaces/IAaveCctpBridge.sol";
import {ITokenMessengerV2} from "./interfaces/ITokenMessengerV2.sol";

/// @title AaveCctpBridge
/// @author stevyhacker (TokenLogic)
/// @notice Helper contract to bridge USDC using Circle's CCTP V2
contract AaveCctpBridge is Ownable, Rescuable, IAaveCctpBridge {
    using SafeERC20 for IERC20;

    /// @notice Finality threshold for Fast Transfer
    uint32 public constant FAST_FINALITY_THRESHOLD = 1000;

    /// @notice Finality threshold for Standard Transfer
    uint32 public constant STANDARD_FINALITY_THRESHOLD = 2000;

    /// @inheritdoc IAaveCctpBridge
    address public immutable TOKEN_MESSENGER;

    /// @inheritdoc IAaveCctpBridge
    address public immutable USDC;

    /// @inheritdoc IAaveCctpBridge
    uint32 public immutable LOCAL_DOMAIN;

    /// @param tokenMessenger The TokenMessengerV2 address on this chain
    /// @param usdc The USDC token address on this chain
    /// @param localDomain The CCTP domain identifier for this chain
    /// @param owner The owner of the contract upon deployment
    constructor(
        address tokenMessenger,
        address usdc,
        uint32 localDomain,
        address owner
    ) Ownable(owner) {
        if (tokenMessenger == address(0)) revert InvalidZeroAddress();
        if (usdc == address(0)) revert InvalidZeroAddress();

        TOKEN_MESSENGER = tokenMessenger;
        USDC = usdc;
        LOCAL_DOMAIN = localDomain;
    }

    /// @inheritdoc IAaveCctpBridge
    function bridge(
        uint32 destinationDomain,
        uint256 amount,
        address receiver,
        uint256 maxFee,
        TransferSpeed speed
    ) external onlyOwner {
        if (amount < 1) revert InvalidZeroAmount();
        if (receiver == address(0)) revert InvalidReceiver();
        if (destinationDomain == LOCAL_DOMAIN) revert InvalidDestinationDomain();

        uint32 finalityThreshold = STANDARD_FINALITY_THRESHOLD;
        if (speed == TransferSpeed.Fast) {
            finalityThreshold = FAST_FINALITY_THRESHOLD;
        }

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(USDC).forceApprove(TOKEN_MESSENGER, amount);

        ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
            amount,
            destinationDomain,
            _addressToBytes32(receiver),
            USDC,
            bytes32(0),
            maxFee,
            finalityThreshold
        );

        emit Bridge(USDC, destinationDomain, receiver, amount, speed);
    }

    /// @inheritdoc Rescuable
    function whoCanRescue() public view override returns (address) {
        return owner();
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(address) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
        return type(uint256).max;
    }

    /// @dev Converts an address to bytes32 for CCTP
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
