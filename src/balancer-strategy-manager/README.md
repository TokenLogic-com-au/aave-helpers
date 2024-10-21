# Balancer V2 Weighted Pool Strategy Manager

## Overview

This Solidity contract, `BalancerV2WeightedPoolStrategyManager`, allows managing liquidity in a **Balancer V2 Weighted Pool** by facilitating deposits and withdrawals of tokens. It integrates with the Balancer Vault and enables owners and guardians to deposit tokens into a Balancer pool, mint **Balancer Pool Tokens (BPT)**, and withdraw liquidity when needed.

The contract uses a **token configuration** system to manage token providers, and features access control mechanisms for security, allowing only the owner, guardian, or a designated **Hypernative** service to withdraw tokens in emergencies.

## Features

- **Deposit tokens** into a Balancer V2 Weighted Pool and receive BPT.
- **Withdraw tokens** by burning BPT, either partially or fully.
- **Emergency withdrawal** of tokens by authorized entities in case of emergencies.
- Access control for managing who can perform deposits and withdrawals.
- **Token rescue functionality** for recovering tokens accidentally sent to the contract.

## Dependencies

This contract imports several OpenZeppelin utilities, as well as Balancer-specific interfaces:

- **`IERC20`**: Interface for interacting with ERC20 tokens.
- **`SafeERC20`**: Safe methods for token transfers and approvals.
- **`OwnableWithGuardian`**: Owner and guardian access control management.
- **`Rescuable`**: Allows token recovery by the owner in case of emergencies.
- **Balancer V2 Interfaces**: Interactions with the Balancer V2 pool and vault system.

## Functions

### Constructor

```solidity
constructor(
    address _vault,
    bytes32 _poolId,
    TokenConfig[] memory _tokenConfig,
    address _owner,
    address _guardian,
    address _hypernative
)
```

- **_vault**: The address of the Balancer Vault.
- **_poolId**: The ID of the Balancer pool.
- **_tokenConfig**: The array of token configurations, containing token addresses and their providers.
- **_owner**: The owner address of the contract.
- **_guardian**: The guardian address for managing secure access.
- **_hypernative**: The address of the Hypernative service.

### `setTokenProvider(uint256 _id, address _provider)`

- **Purpose**: Updates the token provider for a specific token.
- **Access**: Only the owner can call this function.

### `deposit(uint256[] calldata _tokenAmounts)`

- **Purpose**: Deposits tokens into the Balancer pool and receives BPT tokens.
- **Parameters**: `_tokenAmounts` is an array of token amounts for each pool token.
- **Access**: Can be called by the owner or guardian.

### `withdraw(uint256 bpt)`

- **Purpose**: Withdraws tokens by burning a specific amount of BPT.
- **Parameters**: `bpt` is the amount of Balancer Pool Tokens (BPT) to burn.
- **Returns**: An array representing the amounts of each token withdrawn.
- **Access**: Can be called by the owner or guardian.

### `emergencyWithdraw()`

- **Purpose**: Withdraws all tokens by burning the entire BPT balance. This function is intended for emergency situations.
- **Returns**: An array representing the amounts of each token withdrawn.
- **Access**: Can be called by the owner, guardian, or the Hypernative service.

### `getTokenConfig(uint256 id)`

- **Purpose**: Retrieves the token configuration (token and provider) for a given token index.
- **Returns**: A `TokenConfig` struct containing the token address and provider.

### Rescue Functions

The contract allows the owner to rescue tokens sent to the contract by accident:

- **`whoCanRescue()`**: Returns the address that can perform a token rescue (the owner).
- **`maxRescue()`**: Defines the maximum amount of tokens that can be rescued (set to the maximum `uint256` value).

### Internal Functions

- **`_withdraw(uint256 bptAmount)`**: Internal function to handle withdrawal of tokens from the pool.
- **`_sendTokensToProvider()`**: Sends remaining token balances back to their respective providers.
- **`_sendTokenToProvider(IERC20 token, address provider)`**: Sends the remaining balance of a single token to its provider.

## Access Control

- **Owner**: Can perform all actions (deposits, withdrawals, setting token providers, and rescuing tokens).
- **Guardian**: Has the same rights as the owner for deposits and withdrawals.
- **Hypernative**: Can only perform emergency withdrawals.

## Errors

- **`TokenMismatch()`**: Thrown when a mismatch between the actual tokens in the pool and the provided token configuration is detected.
- **`TokenCountMismatch()`**: Thrown when the number of tokens provided does not match the pool's token count.
- **`InsufficientToken(address token)`**: Thrown when attempting to deposit an amount of tokens that exceeds the contract's balance.
- **`Unauthorized()`**: Thrown when an unauthorized user attempts to access restricted functions.

## Security Considerations

- Only the owner, guardian, or the Hypernative address can perform withdrawals to ensure secure access to pool funds.
- Token mismatches and token count mismatches will revert the transaction, ensuring pool integrity.
- Rescuable functionality allows the contract owner to recover mistakenly sent tokens.
