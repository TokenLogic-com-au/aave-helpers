// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Balancer Strategy Manager Interface
 * @notice Interface for managing token deposits and withdrawals from a Balancer pool.
 * @dev This contract allows depositing tokens into the Balancer pool to receive BPT tokens and
 *      withdrawing tokens by burning BPT tokens. It also provides an emergency withdrawal mechanism.
 */
interface IBalancerStrategyManager {
  /**
   * @dev Emits when token provider updated
   * @param token The address of token
   * @param oldProvider The address of old provider
   * @param newProvider The address of new provider
   */
  event TokenProviderUpdated(address indexed token, address oldProvider, address newProvider);

  /**
   * @dev Emits when deposit to pool
   * @param operator The address of operator
   * @param poolId The id of balancer pool.
   * @param tokenAmounts The amount of tokens
   * @param bptAmount The amount of bpt
   */
  event TokenDeposit(
    address indexed operator,
    bytes32 indexed poolId,
    uint256[] tokenAmounts,
    uint256 bptAmount
  );

  /**
   * @dev Emits when withdraw from pool
   * @param operator The address of operator
   * @param poolId The id of balancer pool.
   * @param tokenAmounts The amount of tokens
   * @param bptAmount The amount of bpt
   */
  event TokenWithdraw(
    address indexed operator,
    bytes32 indexed poolId,
    uint256[] tokenAmounts,
    uint256 bptAmount
  );

  /// @notice Error thrown when there is a mismatch between token addresses
  error TokenMismatch();

  /// @notice Error thrown when the number of tokens provided does not match the pool's token count
  error TokenCountMismatch();

  /**
   * @notice Error thrown when the contract has insufficient token balance
   * @param token The address of the token with insufficient balance
   * @param currentBalance Current balance of token
   */
  error InsufficientToken(address token, uint256 currentBalance);

  /// @notice Error thrown when a non-authorized address attempts to call a restricted function
  error Unauthorized();

  /**
   * @notice Token configuration details.
   * @dev Contains the token address and the corresponding token provider's address.
   */
  struct TokenConfig {
    address token; ///< The address of the token.
    address provider; ///< The address of the token provider.
  }

  /**
   * @notice Returns the address of the token provider.
   * @dev Returns the address of the token provider.
   * @param token The address of the token
   * @return provider The token configuration, including the token address and provider address.
   */
  function tokenProvider(address token) external view returns (address provider);

  /**
   * @notice Sets the token provider for a specific token.
   * @dev Only callable by the owner of the contract.
   * @param token The index of the token to update.
   * @param provider The address of the new token provider.
   */
  function setTokenProvider(address token, address provider) external;

  /**
   * @notice Deposits tokens into the Balancer pool.
   * @dev Deposits the maximum balance of the provided tokens into the Balancer pool.
   *      The contract will hold the BPT (Balancer Pool Token) after the deposit.
   * @param poolId The id of balancer pool to deposit
   * @param tokens The amounts of each token to deposit.
   */
  function deposit(bytes32 poolId, uint256[] calldata tokens) external;

  /**
   * @notice Withdraws tokens from the Balancer pool by burning a specified amount of BPT.
   * @dev Burns the given amount of BPT and withdraws the corresponding amounts of tokens from the Balancer pool.
   * @param poolId The id of balancer pool to deposit
   * @param bpt The amount of BPT to burn.
   * @return tokens The amounts of tokens withdrawn.
   */
  function withdraw(bytes32 poolId, uint256 bpt) external returns (uint256[] memory tokens);

  /**
   * @notice Emergency withdrawal of tokens from the Balancer pool.
   * @dev Burns all the BPT held by the contract and withdraws all associated tokens from the Balancer pool.
   * @param poolId The id of balancer pool to deposit
   * @return tokens The amounts of tokens withdrawn.
   */
  function emergencyWithdraw(bytes32 poolId) external returns (uint256[] memory tokens);
}
