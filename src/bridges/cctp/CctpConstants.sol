// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CctpConstants
/// @notice Constants for CCTP V2 bridge testing
/// @dev Domain IDs from https://developers.circle.com/cctp/cctp-supported-blockchains
contract CctpConstants {
    // CCTP Domain IDs
    uint32 public constant ETHEREUM_DOMAIN = 0;
    uint32 public constant AVALANCHE_DOMAIN = 1;
    uint32 public constant OPTIMISM_DOMAIN = 2;
    uint32 public constant ARBITRUM_DOMAIN = 3;
    uint32 public constant SOLANA_DOMAIN = 5;
    uint32 public constant BASE_DOMAIN = 6;
    uint32 public constant POLYGON_DOMAIN = 7;
    uint32 public constant UNICHAIN_DOMAIN = 10;
    uint32 public constant LINEA_DOMAIN = 11;

    // Finality Thresholds
    uint32 public constant FAST_FINALITY_THRESHOLD = 1000;
    uint32 public constant STANDARD_FINALITY_THRESHOLD = 2000;

    // Mainnet TokenMessengerV2 addresses
    // https://etherscan.io/address/0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
    address public constant ETHEREUM_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    // https://arbiscan.io/address/0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
    address public constant ARBITRUM_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    // https://basescan.org/address/0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
    address public constant BASE_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    // https://optimistic.etherscan.io/address/0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
    address public constant OPTIMISM_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    // https://polygonscan.com/address/0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d
    address public constant POLYGON_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;

    // Mainnet USDC addresses
    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public constant ETHEREUM_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // https://arbiscan.io/address/0xaf88d065e77c8cC2239327C5EDb3A432268e5831
    address public constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    // https://basescan.org/address/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // https://optimistic.etherscan.io/address/0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
    address public constant OPTIMISM_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    // https://polygonscan.com/address/0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
    address public constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
}
