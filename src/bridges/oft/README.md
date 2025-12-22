# AaveOFTBridge

The AaveOFTBridge is a contract to facilitate moving USDT between networks using USDT0 OFT (Omnichain Fungible Token) via LayerZero V2. This provides seamless, 1:1 cross-chain USDT transfers with no slippage.

## How USDT0 Works

USDT0 is Tether's official cross-chain solution using LayerZero's OFT standard. It enables unified USDT liquidity across chains without wrapped tokens.

### Architecture

- **On Ethereum**: Uses `OAdapterUpgradeable` which locks native USDT and sends LayerZero message
- **On Other Chains**: Uses `OUpgradeable` which mints/burns USDT0

### Key Benefits

- **No Slippage**: 1:1 lock/mint mechanism (unlike liquidity pool bridges)
- **Unified Liquidity**: All USDT0 is backed 1:1 by USDT on Ethereum
- **Dual DVN Security**: Verified by both LayerZero DVN and USDT0 DVN

## Functions

### `bridge()`

Bridges USDT to a destination chain. The contract must hold the USDT tokens and have or receive sufficient native tokens for the LayerZero messaging fee.

### `quoteBridge()`

Returns the native token fee required for bridging. Call this before `bridge()` to know how much native token to send.

### `quoteOFT()`

Returns the expected amount to be received on the destination chain. Use this value as `minAmountLD` in the `bridge()` call.

For USDT0 OFT transfers, this should return the same amount (1:1, no slippage).

## Usage Pattern

```solidity
// 1. Quote the expected received amount
uint256 expectedReceived = bridge.quoteOFT(dstEid, amount, receiver);

// 2. Quote the native fee
uint256 fee = bridge.quoteBridge(dstEid, amount, receiver, expectedReceived);

// 3. Transfer USDT to the bridge contract
IERC20(usdt).transfer(address(bridge), amount);

// 4. Ensure bridge has native tokens for fees
// (can be sent beforehand or via governance proposal)

// 5. Execute the bridge
bridge.bridge(dstEid, amount, receiver, expectedReceived);
```

## Permissions

The contract implements `Ownable` for permissioned functions. The owner should be the respective network's Level 1 Executor (Governance).

Only the owner can:
- Call `bridge()` to initiate transfers
- Call `emergencyTokenTransfer()` to rescue tokens
- Transfer ownership

## Security Considerations

- The contract inherits from `Rescuable`, allowing token rescue in case of issues
- Slippage protection via `minAmountLD` parameter prevents receiving less than expected
- The `quoteOFT()` function should be called immediately before bridging to get accurate amounts
- Only the owner (governance) can execute bridges

## Retry Mechanism

LayerZero includes a retry mechanism to handle transactions which fail to execute on the destination chain.

Because LayerZero separates the verification of a message from its execution, if a message fails to execute, it can be retried without having to resend it from the origin chain. This is possible because the message has already been confirmed by the DVNs as a valid message packet, meaning execution can be retried at any time, by anyone.

### How to Retry

To retry a failed message:

1. **LayerZero Scan Interface**: Use the [LayerZero Scan](https://layerzeroscan.com/) UI to locate and retry the failed message
2. **Direct Contract Call**: Call the `lzReceive` function directly on the Endpoint contract

For more details, see the [LayerZero debugging documentation](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages#retry-message).

## Supported Chains

USDT0 is currently deployed on the following chains:

### Endpoint IDs and OFT Contracts

| Chain | Endpoint ID | USDT0 OFT Contract | Notes |
|-------|------------|-------------------|-------|
| Ethereum | 30101 | 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee | OAdapterUpgradeable (locks USDT) |
| Arbitrum | 30110 | 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92 | OUpgradeable |
| Polygon | 30109 | 0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13 | OUpgradeable |
| Optimism | 30111 | 0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD | OUpgradeable |
| Ink | 30339 | 0x0200C29006150606B650577BBE7B6248F58470c1 | OUpgradeable |
| Plasma | 30383 | 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9 | OUpgradeable |

### USDT Token Addresses

| Chain | USDT/USDT0 Token |
|-------|-----------------|
| Ethereum | 0xdAC17F958D2ee523a2206206994597C13D831ec7 |
| Arbitrum | 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9 |
| Polygon | 0xc2132D05D31c914a87C6611C10748AEb04B58e8F |
| Optimism | 0x01bFF41798a0BcF287b996046Ca68b395DbC1071 |
| Ink | 0x0200C29006150606B650577BBE7B6248F58470c1 |
| Plasma | 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb |

### Not Supported

| Chain | Reason |
|-------|--------|
| Avalanche | No USDT0 deployment |
| Base | No USDT0 deployment |

## Known Limitations

1. **Same Asset Only**: Only USDT-to-USDT bridging is supported.

2. **LayerZero Fees**: A small native token fee is required for the LayerZero messaging. Use `quoteBridge()` to get the exact fee.

## References

- [USDT0 Documentation](https://docs.usdt0.to/)
- [USDT0 Deployments](https://docs.usdt0.to/technical-documentation/developer/usdt0-deployments)
- [LayerZero V2 OFT Standard](https://docs.layerzero.network/v2/developers/evm/oft/native-transfer)
