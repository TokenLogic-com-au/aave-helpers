// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenMessengerV2} from "src/bridges/cctp/interfaces/ITokenMessengerV2.sol";

/// @title MockTokenMessengerV2
/// @notice Mock implementation of Circle's CCTP V2 TokenMessenger for testing
contract MockTokenMessengerV2 is ITokenMessengerV2 {
    using SafeERC20 for IERC20;

    address public immutable messageTransmitter;
    uint64 public nextNonce;
    uint256 public mockMinFee;

    // Track deposits for verification
    struct DepositRecord {
        uint256 amount;
        uint32 destinationDomain;
        bytes32 mintRecipient;
        address burnToken;
        bytes32 destinationCaller;
        uint256 maxFee;
        uint32 minFinalityThreshold;
    }

    mapping(uint64 => DepositRecord) public deposits;

    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    );

    constructor(address _messageTransmitter) {
        messageTransmitter = _messageTransmitter;
        nextNonce = 1;
        mockMinFee = 0;
    }

    function setMockMinFee(uint256 _minFee) external {
        mockMinFee = _minFee;
    }

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external override returns (uint64) {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from sender to this contract (simulating burn)
        IERC20(burnToken).safeTransferFrom(msg.sender, address(this), amount);

        uint64 nonce = nextNonce++;

        deposits[nonce] = DepositRecord({
            amount: amount,
            destinationDomain: destinationDomain,
            mintRecipient: mintRecipient,
            burnToken: burnToken,
            destinationCaller: destinationCaller,
            maxFee: maxFee,
            minFinalityThreshold: minFinalityThreshold
        });

        emit DepositForBurn(
            nonce,
            burnToken,
            amount,
            msg.sender,
            mintRecipient,
            destinationDomain,
            destinationCaller,
            maxFee,
            minFinalityThreshold
        );

        return nonce;
    }

    function getMinFeeAmount(
        uint32, /* destinationDomain */
        address, /* burnToken */
        uint256 /* amount */
    ) external view override returns (uint256) {
        return mockMinFee;
    }

    function localMessageTransmitter() external view override returns (address) {
        return messageTransmitter;
    }

    /// @notice Helper to get deposit record for verification in tests
    function getDeposit(uint64 nonce) external view returns (DepositRecord memory) {
        return deposits[nonce];
    }
}
