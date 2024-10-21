// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBalancerStrategyManager {
  struct TokenConfig {
    address token;
    address provider;
  }

  /**
   * @notice Returns address of token and token provider
   * @param id The index of token
   * @return config The config of token
   */
  function getTokenConfig(uint256 id) external view returns (TokenConfig memory config);

  /**
   * @notice Deposit tokens into Balancer pool and hold BPT token on contract
   * @dev Deposits maximum balance of tokens into the Balancer pool
   * @param tokens The amounts of token
   */
  function deposit(uint256[] calldata tokens) external;

  /**
   * @notice Burn BPT token and withdraw tokens from Balancer pool
   * @dev Burn specific amount of BPT and withdraw tokens from Balancer pool
   * @param bpt The amount of BPT
   * @return tokens The amounts of token
   */
  function withdraw(uint256 bpt) external returns (uint256[] memory tokens);

  /**
   * @notice Burn BPT token and withdraw tokens from Balancer pool
   * @dev Burn all of BPT and withdraw tokens from Balancer pool
   * @return tokens The amounts of token
   */
  function emergencyWithdraw() external returns (uint256[] memory tokens);
}
