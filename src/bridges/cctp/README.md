# Aave CCTP Bridge

The AaveCctpBridge is a contract to facilitate bridging USDC across chains using Circle's Cross-Chain Transfer Protocol (CCTP) V2. The contract provides a simplified interface for Aave DAO governance to move USDC between supported networks.

## Features

- Bridge USDC to any CCTP V2 supported destination chain
- Support for both Fast and Standard transfer speeds
- Owner-controlled access for secure treasury management

## Transfer Speeds

CCTP V2 supports two transfer speed modes:

| Speed    | Finality Threshold | Description                      |
| -------- | ------------------ | -------------------------------- |
| Fast     | 1000               | Faster transfer, may incur a fee |
| Standard | 2000               | Slower transfer, no fee          |

Essentially, the Fast mode is just a tx confirmation is sufficient while the Standard mode requires hard finality and a large number of mined blocks.
The exact numbers per chain can be found in the Circle documentation:

- [cctp-fast-message-attestation-times](https://developers.circle.com/cctp/required-block-confirmations#cctp-fast-message-attestation-times)
- [cctp-standard-message-attestation-times](https://developers.circle.com/cctp/required-block-confirmations#cctp-standard-message-attestation-times)

The `maxFee` parameter allows specifying the maximum fee (in USDC) willing to pay for Fast transfers.

- For `TransferSpeed.Fast`, `maxFee` is the maximum fee you are willing to pay (in USDC base units).
- For `TransferSpeed.Standard`, fees are `0` (per Iris) so `maxFee` should be set to `0`.

### Querying fees for Fast transfers

Circle exposes the minimum fee rate for a route (in basis points) via Iris. To derive a `maxFee` for `TransferSpeed.Fast`, query:

Example:

```bash
# Arbitrum (3) -> Base (6)
curl -s "https://iris-api.circle.com/v2/burn/USDC/fees/3/6"
```

- Mainnet: `GET https://iris-api.circle.com/v2/burn/USDC/fees/{sourceDomainId}/{destDomainId}`
- Testnet: `GET https://iris-api-sandbox.circle.com/v2/burn/USDC/fees/{sourceDomainId}/{destDomainId}`

The response includes entries for `finalityThreshold` `1000` (Fast / Confirmed) and `2000` (Standard / Finalized).

To derive a `maxFee` for `TransferSpeed.Fast`, use the `minimumFee` where `finalityThreshold == 1000`, then compute (rounding up):

`maxFee = ceil(amount * minimumFee / 10_000)`

**Denomination / decimals**

- Onchain, both `amount` and `maxFee` are expected in the token’s smallest unit (for USDC: `6` decimals, i.e. `1 USDC = 1_000_000` base units).
- The Iris API returns a fee _rate_ (`minimumFee` in bps). This value can be fractional (e.g. `1.3` bps), so do the computation off-chain using decimal math and then round up to base units.

Example (1000 USDC, `minimumFee = 1.3` bps):

- `amountBaseUnits = 1000 * 1_000_000 = 1_000_000_000`
- choose `scale = 10` (one decimal place), so `minimumFeeScaled = 13`
- `maxFeeBaseUnits = ceil(1_000_000_000 * 13 / (10_000 * 10)) = 130_000`
- `130_000` base units = `0.13` USDC

Note: the API returns a fee _rate_ (`minimumFee` in bps), not a precomputed absolute `maxFee`; you derive the absolute value from your `amount`.

## Permissions

The contract implements `Ownable` for permissioned functions.
The Owner will always be the respective network's Level 1 Executor (Governance).

Only the owner can call the `bridge()` function to initiate transfers.

## Security Considerations

The contract inherits from `Rescuable`. Using the inherited functions, the owner can transfer tokens out from this contract in case of emergency or stuck funds.

## CCTP Domain IDs

Domain IDs are defined by Circle's CCTP. The complete list can be found in the [CCTP documentation](https://developers.circle.com/cctp/cctp-supported-blockchains).

| Network   | Domain ID |
| --------- | --------- |
| Ethereum  | 0         |
| Avalanche | 1         |
| Optimism  | 2         |
| Arbitrum  | 3         |
| Solana    | 5         |
| Base      | 6         |
| Polygon   | 7         |
| Unichain  | 10        |
| Linea     | 11        |
| Sonic     | 13        |
| Monad     | 15        |
| Ink       | 21        |

## Functions

```solidity
function bridge(
  uint32 destinationDomain,
  uint256 amount,
  address receiver,
  uint256 maxFee,
  TransferSpeed speed
) external onlyOwner;
```

Bridges USDC to a destination chain. The caller (owner) must have approved the bridge contract to spend the specified amount of USDC. Upon execution, the USDC is burned on the source chain and minted on the destination chain to the receiver address.

Parameters:

- `destinationDomain`: The CCTP domain ID of the destination chain
- `amount`: Amount of USDC to bridge (must be > 0)
- `receiver`: Recipient address on the destination chain
- `maxFee`: Maximum fee in USDC for Fast transfers
- `speed`: `TransferSpeed.Fast` or `TransferSpeed.Standard`

## Contract Addresses

### TokenMessengerV2 (CCTP V2)

All networks use the same TokenMessengerV2 address: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`

### Native USDC Addresses

| Network  | USDC Address                                 |
| -------- | -------------------------------------------- |
| Ethereum | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Arbitrum | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| Base     | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Optimism | `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85` |
| Polygon  | `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359` |

## References

- [CCTP V2 Documentation](https://developers.circle.com/cctp)
- [CCTP Supported Blockchains](https://developers.circle.com/cctp/cctp-supported-blockchains)
