# Aave Base -> Mainnet ERC20 Bridge

Currently there is no easy way for the Collector on Base to withdraw funds via bridging to Ethereum mainnet. An upgrade to the Collector to be made to bridge directly, however, with this approach, we can assign a Guardian the role to bridge as is done with other networks such as Polygon and Arbitrum.

The official Base documentation can be found [here](https://docs.base.org).

## Functions

`function bridge(address token, address l1Token, uint256 amount) external onlyOwner`

Callable on Base. Withdraws an ERC20 from Base to Mainnet. The ERC20 token must be a BaseBurnableERC20 in order to be bridged.
The first parameter is the token's address on Base, while the second one is the token's equivalent address on Mainnet (ie: USDC on Base and USDC on Mainnet). The last parameter is the amount of tokens to bridge.

`function emergencyTokenTransfer(address erc20Token, address to, uint256 amount) external;`

Callable on Base. In case of emergency can be called by the owner to withdraw tokens from bridge contract back to any address on Base.

## Proving The Message

In order to finalize the bridge from Base to Mainnet, there are two steps required. Firstly, one must prove the message. Unfortunately, there's no way to do this on-chain with Foundry so we have to rely on the Base SDK by utilizing TokenLogic's CLI tool (forked off of BGD's aave-cli).

[The CLI tool can be found here](https://github.com/TokenLogic-com-au/aave-cli-tools).

The first command can be run a few minutes to an hour after the bridge transaction takes place.

The script can be run with the following command:

`yarn start base-prove-message <TX_HASH> <INDEX>` where TX_HASH is the transaction hash where the bridge took place and INDEX is the index of the ERC20 token in terms of how many tokens were bridged in the same transaction. For just one token, INDEX will be 0. For multiple, start from 0 and go up by one.

Once the message is proven, around 7 days later from the transaction, it will be available to be finalized as Base is an optimistic rollup.

## Finalizing

[The CLI can be found here](https://github.com/TokenLogic-com-au/aave-cli-tools).

Just like when proving the message, there's a command in order to finalize the bridge.

`yarn start base-finalize-bridge <TX_HASH> <INDEX>` where TX_HASH is the transaction hash where the bridge took place and INDEX is the index of the ERC20 token in terms of how many tokens were bridged in the same transaction. For just one token, INDEX will be 0. For multiple, start from 0 and go up by one.

## Transactions

| Token  | Bridge                                                                                                     | Prove                                                                                            | Finalize                                                                                        |
| ------ | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| USDC | [Tx](https://basescan.org/tx/0x1597ea1a99e66f077d7ef6f2236036f4a75aabb9063b4b3ced75ba62653d8d7f) | [Tx](https://etherscan.io/tx/0xd70544e57bc395ae6f5ea9e634c6eb4bef226cd6d93efc5006aa940497026f18) | [Tx](https://etherscan.io/tx/0x9039bb87ba613e82c2fa6dfce78657d2d79c86926f0b3c80cd1fe82ea708c303) |

## Deployed Address

Optimism [0xe0401d2996f29b2bda1628125606bff8ab4be67e](https://basescan.org/address/0xe0401d2996f29b2bda1628125606bff8ab4be67e)
