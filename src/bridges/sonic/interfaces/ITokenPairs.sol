// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// The token pairs registry maps Ethereum ERC-20 tokens to L2 tokens minted by the bridge.
interface ITokenPairs {
  /// Map Ethereum token to L2 token - pairs can be only added into this mapping.
  function originalToMinted(address) external view returns (address);

  /// Map Ethereum token to L2 token - pairs can be removed from here to block new transfers.
  function originalToMintedTerminable(address) external view returns (address);

  /// Map L2 token to Ethereum token - pairs can be only added into this mapping.
  function mintedToOriginal(address) external view returns (address);

  /// Check if the account has given role - allows to use TokenPairs as an AccessManager for USDC burning ops.
  function hasRole(bytes32 role, address account) external view returns (bool);
}
