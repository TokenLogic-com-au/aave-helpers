# Aave CCTP Bridge

## Overview

The `AaveCctpBridge` smart contract allows for bridging **USDC** between EVM-compatible chains using the CCTP (Circle Cross-Chain Transfer Protocol). This contract is built with a focus on decentralized finance (DeFi) applications and enables the seamless transfer of USDC from one blockchain to another. It includes support for ownership and guardian roles, token rescuing, and the management of message transmissions for secure cross-chain operations.

## Features

- **Bridge USDC**: Allows USDC to be bridged to other EVM-compatible chains.
- **Message Transmission**: Uses Circle's CCTP messaging and token transmitter to handle USDC cross-chain transfers.
- **Ownership and Guardian Role**: Ownership management and a guardian role for enhanced security.
- **Rescue Functions**: Recover tokens that may be stuck in the contract using the `Rescuable` mechanism.

## Contract Details

### Constructor Parameters

The constructor requires the following parameters during deployment:

- `_tokenMessenger`: Address of the CCTP token messenger contract.
- `_messageTransmitter`: Address of the CCTP message transmitter contract.
- `_usdc`: Address of the USDC contract (ERC20).
- `_owner`: Address of the contract owner.
- `_guardian`: Address of the contract guardian.

### Public Variables

- `TOKEN_MESSENGER`: The address of the CCTP token messenger.
- `MESSAGE_TRANSMITTER`: The address of the CCTP message transmitter.
- `USDC`: The address of the USDC token (ERC20).
- `collectors`: A mapping that stores the address of the collector on a destination chain, mapped by the chain's ID.

### Functions

#### `bridgeUsdc(uint32 _toChainId, uint256 _amount)`

- Bridges USDC from the current chain to the destination chain.
- The function reverts with `InvalidChain` if the destination chain is not supported.
- Reverts with `ZeroAmount` if the amount to bridge is zero.
- Transfers USDC from the caller to the contract and approves the token messenger if needed.
- Uses the CCTP token messenger to deposit the USDC for burning on the source chain and minting on the destination chain.

**Modifiers**: 
- Can be called only by the owner or guardian.

#### `receiveUsdc(bytes calldata _message, bytes calldata _attestation)`

- Receives USDC on the destination chain.
- Verifies the message using the CCTP message transmitter.

#### `setCollector(uint32 _toChainId, address _collector)`

- Sets the address of the collector on the destination chain.
- Can only be called by the owner.

#### `whoCanRescue()`

- Overrides the `Rescuable` contract’s function to return the current owner, indicating who has the rescue permission.

### Events

- `BridgeMessageSent(uint32 indexed _toChainId, uint256 _amount)`: Emitted when a USDC bridge message is sent.
- `BridgeMessageReceived(bytes _message)`: Emitted when a USDC bridge message is received.
- `CollectorUpdated(uint32 indexed _toChainId, address _collector)`: Emitted when a collector address is updated.

## Dependencies

The contract uses the following external dependencies:

- `IAaveCctpBridge`: Interface for the Aave CCTP bridge operations.
- `ICctpMessageTransmitter`: Interface for handling CCTP messages.
- `ICctpTokenMessenger`: Interface for the CCTP token messenger, which facilitates token transfers between chains.
- `IERC20`: ERC20 interface used for USDC token interactions.
- `OwnableWithGuardian`: Provides ownership and guardian roles for secure access control.
- `Rescuable`: A utility contract to rescue tokens accidentally sent to the contract.

## Installation

To deploy and interact with this contract, ensure you have the following:

- **Solidity Compiler**: Version `0.8.0` or above.
- **Node.js and Hardhat** (optional): For compiling and deploying the contract.
- **Dependencies**:
  - Aave’s Solidity utils for `OwnableWithGuardian` and `Rescuable`.
  - The relevant CCTP interfaces.

## Usage

1. **Deploy the Contract**: Pass the appropriate constructor parameters such as the token messenger, message transmitter, USDC contract address, owner, and guardian.
2. **Set Collectors**: Use `setCollector` to configure the destination chain’s collector.
3. **Bridge USDC**: Call `bridgeUsdc` to transfer USDC from one chain to another.
4. **Receive USDC**: The receiver chain must handle the message and attestation using the `receiveUsdc` function.
