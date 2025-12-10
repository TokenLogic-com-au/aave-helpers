// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenMessengerV2} from "src/bridges/cctp/interfaces/ITokenMessengerV2.sol";

/// @title MockTokenMessengerV2
/// @notice Mock implementation of Circle's CCTP V2 TokenMessenger for testing
contract MockTokenMessengerV2 is ITokenMessengerV2 {
    using SafeERC20 for IERC20;

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

    uint64 public _nextNonce;

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

    /// @dev Amount must be greater than zero
    error InvalidAmount();

    constructor(address) {
        _nextNonce = 1;
    }

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external override {
        if (amount < 1) revert InvalidAmount();

        // Transfer tokens from sender to this contract (simulating burn)
        IERC20(burnToken).safeTransferFrom(msg.sender, address(this), amount);

        uint64 nonce = _nextNonce++;

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
    }

    /// @notice Helper to get deposit record for verification in tests
    function getDeposit(uint64 nonce) external view returns (DepositRecord memory) {
        return deposits[nonce];
    }
}
