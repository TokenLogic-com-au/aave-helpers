// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBalancerStrategyManager {
  /**
   * @notice Deposit tokens into Balancer pool and hold BPT token on contract
   * @dev Deposits maximum balance of tokens into the Balancer pool
   * @param tokens The amounts of token
   * @return bpt The amount of BPT
   */
  function deposit(uint256[] calldata tokens) external returns (uint256 bpt);

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
