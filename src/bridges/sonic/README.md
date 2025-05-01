# AaveSonicEthERC20Bridge

## Overview

The `AaveSonicEthERC20Bridge` is a smart contract designed to facilitate the bridging of ERC20 tokens between Ethereum Mainnet and Sonic (a Layer 2 solution). This contract is part of the Aave ecosystem and is specifically tailored to interact with the Aave V3 protocol on both Ethereum Mainnet and Sonic. The contract allows for the deposit and withdrawal of tokens, as well as claiming bridged tokens and withdrawing funds to the Aave collector.

## Features

- **Deposit Tokens**: Deposit ERC20 tokens from Ethereum Mainnet to Sonic.
- **Withdraw Tokens**: Withdraw ERC20 tokens from Sonic back to Ethereum Mainnet.
- **Claim Tokens**: Claim tokens that have been bridged to the opposite chain using generated proofs.
- **Withdraw to Collector**: Withdraw ERC20 tokens or ETH to the Aave collector on either Ethereum Mainnet or Sonic.
- **Rescue Mechanism**: Allows for the rescue of funds in case of accidental transfers.

## Contract Details

### Dependencies

- **OpenZeppelin Contracts**: The contract uses OpenZeppelin's `IERC20` and `SafeERC20` libraries for safe ERC20 token interactions.
- **Solidity Utils**: The contract inherits from `OwnableWithGuardian`, `PermissionlessRescuable`, and `RescuableBase` for access control and rescue functionality.
- **Aave Address Book**: The contract interacts with Aave V3 addresses on both Ethereum Mainnet and Sonic.
- **Interfaces**: Custom interfaces for bridging, token pairs, and bridged adapters are used to interact with external contracts.

### Constants

- `MAINNET_BRIDGE`: The address of the bridge contract on Ethereum Mainnet.
- `SONIC_BRIDGE`: The address of the bridge contract on Sonic.
- `SONIC_TOKEN_PAIR`: The address of the token pair contract on Sonic.

### Functions

#### Deposit

- **`deposit(address token, uint256 amount)`**: Deposits a single ERC20 token from Ethereum Mainnet to Sonic. Only callable by the owner or guardian.
- **`deposit(address[] memory tokens, uint256[] memory amounts)`**: Deposits multiple ERC20 tokens from Ethereum Mainnet to Sonic. Only callable by the owner or guardian.

#### Withdraw

- **`withdraw(address originalToken, uint256 amount)`**: Withdraws a single ERC20 token from Sonic back to Ethereum Mainnet. Only callable by the owner or guardian.
- **`withdraw(address[] memory originalTokens, uint256[] memory amounts)`**: Withdraws multiple ERC20 tokens from Sonic back to Ethereum Mainnet. Only callable by the owner or guardian.

#### Claim

- **`claim(uint256 id, address token, uint256 amount, bytes calldata proof)`**: Claims tokens that have been bridged to the opposite chain using a generated proof. Can be called by anyone.

#### Withdraw to Collector

- **`withdrawToCollector(address token)`**: Withdraws ERC20 tokens to the Aave collector on the current chain. Only callable by the owner or guardian.
- **`withdrawEthToCollector()`**: Withdraws ETH to the Aave collector on the current chain. Only callable by the owner or guardian.

#### Rescue

- **`maxRescue(address erc20Token)`**: Returns the maximum amount of tokens that can be rescued.
- **`whoShouldReceiveFunds()`**: Returns the address that should receive rescued funds (Aave collector on Ethereum Mainnet).

### Events

- **`Bridge(address indexed token, uint256 amount)`**: Emitted when tokens are deposited or withdrawn.
- **`Claim(address indexed token, uint256 amount)`**: Emitted when tokens are claimed.
- **`WithdrawToCollector(address indexed token, uint256 amount)`**: Emitted when tokens or ETH are withdrawn to the Aave collector.

## Usage

### Deployment

The contract is deployed with an owner and guardian address. These addresses have special permissions to execute certain functions.
_Note: Bridge contract should be deployed to same address on Mainnet and Sonic_

### Interactions

1. **Deposit Tokens**: Call `deposit` with the token address and amount to bridge tokens from Ethereum Mainnet to Sonic.
2. **Withdraw Tokens**: Call `withdraw` with the original token address and amount to bridge tokens back from Sonic to Ethereum Mainnet.
3. **Generate Proof and Claim Tokens**: After calling `deposit` or `withdraw`, use the `aave-cli-tools` to generate a proof for the transaction. This proof is then used to claim the tokens on the destination chain.

   Example CLI command:

   ```bash
   yarn start sonic-claim <source_chain_id> <tx_hash> <bridge>
   ```

   - `<source_chain_id>`: The chain ID of the source chain (e.g., Ethereum Mainnet(1) or Sonic(146). Otherwise it returns error).
   - `<tx_hash>`: The transaction hash of the deposit or withdraw transaction.
   - `<bridge>`: The address of the bridge contract on the chain (this address is the same on both chains).

   This command generates the proof for the bridge transaction and automatically claims the tokens on the destination chain.

4. **Withdraw to Collector**: Call `withdrawToCollector` or `withdrawEthToCollector` to move funds to the Aave collector.

## Onchain Tests

Bridge contracts are deployed on [Mainnet](https://etherscan.io/address/0xb7bd405f4a43e9da2d5fbf3066c0c28e46f9306e) and [Sonic](https://sonicscan.org/address/0xb7bd405f4a43e9da2d5fbf3066c0c28e46f9306e)

|      Direct       |                                                                        Tx on Source Chain                                                                         |                                                                      Tx on Destination Chain                                                                      |
| :---------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| Ethereum -> Sonic | [0x039a60a00dc22689e35c51dbee9672fd6a0e354157dcc172753ac0a85bfa7ae7](https://etherscan.io/tx/0x039a60a00dc22689e35c51dbee9672fd6a0e354157dcc172753ac0a85bfa7ae7)  | [0x9dad15790260d4c254683775d2371697f44716fb5d2c7dbb7aa2c1499011bf77](https://sonicscan.org/tx/0x9dad15790260d4c254683775d2371697f44716fb5d2c7dbb7aa2c1499011bf77) |
| Sonic -> Ethereum | [0xebca94b24ede54ec762c585b45d687f9e796da7c656cde433df3d0698d013ae2](https://sonicscan.org/tx/0xebca94b24ede54ec762c585b45d687f9e796da7c656cde433df3d0698d013ae2) | [0x4c600df9566fbfef72cc88d3af8cd3157cff1cd35ba6303136cfc8b592c7d721](https://etherscan.io/tx/0x4c600df9566fbfef72cc88d3af8cd3157cff1cd35ba6303136cfc8b592c7d721)  |

## Supported Tokens

Currently Sonic Gateway supports FTM, USDT, USDC, EURC, WETH, DOLA, SILO, UNI, GEAR, crvUSD, PENDLE and CRV.

## Bridging time estimation

|  Process  | Ethereum -> Sonic | Sonic -> Ethereum |
| :-------: | :---------------: | :---------------: |
|  Deposit  |    15 minutes     |     1 second      |
| Heartbeat |      15 min       |      1 hour       |
|   Claim   |     immediate     |     immediate     |
| Fast Lane |     0.0002 S      |    0.0065 ETH     |

## Security Considerations

- **Access Control**: Only the owner or guardian can execute deposit and withdrawal functions.
- **Chain Validation**: Functions validate the current chain ID to prevent incorrect usage.
- **Rescue Mechanism**: The contract includes a rescue mechanism to recover funds in case of accidental transfers.
