// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Rescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";

import {IAaveCctpBridge} from "./interfaces/IAaveCctpBridge.sol";
import {ITokenMessengerV2} from "./interfaces/ITokenMessengerV2.sol";

/// @title AaveCctpBridge
/// @author stevyhacker (TokenLogic)
/// @notice Helper contract to bridge USDC using Circle's CCTP V2
contract AaveCctpBridge is OwnableWithGuardian, Rescuable, IAaveCctpBridge {
    using SafeERC20 for IERC20;

    /// @notice Finality threshold constant for Fast Transfer is 1000 and means just tx confirmation is sufficient
    /// @dev Required confirmations per chain https://developers.circle.com/cctp/required-block-confirmations#cctp-fast-message-attestation-times
    uint32 public constant FAST = 1000;

    /// @notice Finality threshold constant for Standard Transfer is 2000 and means hard finality is requested
    /// @dev Required confirmations per chain https://developers.circle.com/cctp/required-block-confirmations#cctp-standard-message-attestation-times
    uint32 public constant STANDARD = 2000;

    /// @inheritdoc IAaveCctpBridge
    address public immutable TOKEN_MESSENGER;

    /// @inheritdoc IAaveCctpBridge
    address public immutable USDC;

    /// @inheritdoc IAaveCctpBridge
    uint32 public immutable LOCAL_DOMAIN;

    /// @notice Mapping of destination domain to collector address (bytes32 to support non-EVM chains)
    mapping(uint32 destinationDomain => bytes32 collector) internal _destinations;

    /// @param tokenMessenger The TokenMessengerV2 address on this chain
    /// @param usdc The USDC token address on this chain
    /// @param localDomain The CCTP domain identifier for this chain
    /// @param owner The owner of the contract upon deployment
    /// @param guardian The initial guardian of the contract upon deployment
    constructor(
        address tokenMessenger,
        address usdc,
        uint32 localDomain,
        address owner,
        address guardian
    ) OwnableWithGuardian(owner, guardian) {
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
        uint256 maxFee,
        TransferSpeed speed
    ) external onlyOwnerOrGuardian {
        if (amount < 1) revert InvalidZeroAmount();
        if (destinationDomain == LOCAL_DOMAIN) revert InvalidDestinationDomain();
        bytes32 receiver = _destinations[destinationDomain];
        if (receiver == bytes32(0)) revert CollectorNotConfigured(destinationDomain);

        uint32 finalityThreshold = speed == TransferSpeed.Fast ? FAST : STANDARD;

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(USDC).forceApprove(TOKEN_MESSENGER, amount);

        ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
            amount,
            destinationDomain,
            receiver,
            USDC,
            bytes32(0),
            maxFee,
            finalityThreshold
        );

        emit Bridge(USDC, destinationDomain, receiver, amount, speed);
    }

    /// @inheritdoc IAaveCctpBridge
    function setDestinationCollector(uint32 destinationDomain, address collector) external onlyOwner {
        if (collector == address(0)) revert InvalidZeroAddress();
        _setDestinationCollector(destinationDomain, _addressToBytes32(collector));
    }

    /// @inheritdoc IAaveCctpBridge
    function setDestinationCollectorNonEVM(uint32 destinationDomain, bytes32 collector) external onlyOwner {
        if (collector == bytes32(0)) revert InvalidZeroAddress();
        _setDestinationCollector(destinationDomain, collector);
    }

    /// @inheritdoc IAaveCctpBridge
    function getDestinationCollector(uint32 destinationDomain) external view returns (bytes32) {
        return _destinations[destinationDomain];
    }

    /// @inheritdoc Rescuable
    function whoCanRescue() public view override returns (address) {
        return owner();
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(address) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
        return type(uint256).max;
    }

    function _setDestinationCollector(uint32 destinationDomain, bytes32 collector) internal {
        _destinations[destinationDomain] = collector;
        emit CollectorSet(destinationDomain, collector);
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

}
