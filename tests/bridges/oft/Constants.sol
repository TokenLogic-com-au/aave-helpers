// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title OFT Constants
/// @notice Constants for USDT0 OFT bridge integration via LayerZero V2
/// @dev USDT0 supported chains: Ethereum, Arbitrum, Polygon, Optimism, Ink, Plasma
///      NOT supported: Avalanche, Base (no USDT0 deployment)
/// @dev Addresses from https://docs.usdt0.to/technical-documentation/developer/usdt0-deployments
contract OFTConstants {
    // LayerZero V2 Endpoint IDs
    uint32 public constant ETHEREUM_EID = 30101;
    uint32 public constant POLYGON_EID = 30109;
    uint32 public constant ARBITRUM_EID = 30110;
    uint32 public constant OPTIMISM_EID = 30111;
    uint32 public constant INK_EID = 30339;
    uint32 public constant PLASMA_EID = 30383;

    // USDT0 OFT Contracts - These are the contracts to call send() on for bridging
    // On Ethereum: OAdapterUpgradeable (locks USDT, sends LayerZero message)
    // On other chains: OUpgradeable (burns/mints USDT0)

    /// @dev https://etherscan.io/address/0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee
    address public constant ETHEREUM_USDT0_OFT = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;

    /// @dev https://arbiscan.io/address/0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92
    address public constant ARBITRUM_USDT0_OFT = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;

    /// @dev https://polygonscan.com/address/0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13
    address public constant POLYGON_USDT0_OFT = 0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13;

    /// @dev https://optimistic.etherscan.io/address/0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD
    address public constant OPTIMISM_USDT0_OFT = 0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD;

    /// @dev https://explorer.inkonchain.com/address/0x0200C29006150606B650577BBE7B6248F58470c1
    address public constant INK_USDT0_OFT = 0x0200C29006150606B650577BBE7B6248F58470c1;

    /// @dev https://plasmascan.to/address/0x02ca37966753bDdDf11216B73B16C1dE756A7CF9
    address public constant PLASMA_USDT0_OFT = 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9;

    // USDT/USDT0 Token addresses (the actual ERC20 tokens users hold)
    // On Ethereum: Native USDT (approve to OAdapterUpgradeable before bridging)
    // On other chains: USDT0 token (TetherTokenOFTExtension or equivalent)

    /// @dev https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev https://arbiscan.io/address/0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
    address public constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    /// @dev https://polygonscan.com/address/0xc2132D05D31c914a87C6611C10748AEb04B58e8F
    address public constant POLYGON_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    /// @dev https://optimistic.etherscan.io/address/0x01bFF41798a0BcF287b996046Ca68b395DbC1071
    address public constant OPTIMISM_USDT = 0x01bFF41798a0BcF287b996046Ca68b395DbC1071;

    /// @dev https://explorer.inkonchain.com/address/0x0200C29006150606B650577BBE7B6248F58470c1
    address public constant INK_USDT = 0x0200C29006150606B650577BBE7B6248F58470c1;

    /// @dev https://plasmascan.to/address/0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb
    address public constant PLASMA_USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
}
