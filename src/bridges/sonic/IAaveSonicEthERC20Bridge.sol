// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAaveSonicEthERC20Bridge
 * @author TokenLogic
 * @notice Interface for AaveSonicEthERC20Bridge
 */
interface IAaveSonicEthERC20Bridge {
  /// @dev The called method is not available on this chain
  error InvalidChain();

  /// @dev The original token is invalid
  error InvalidToken();

  /// @dev Parameter length is mismatched in batch mode
  error InvalidParam();

  /// @dev Emitted when a bridge is initiated
  event Bridge(address indexed token, uint256 amount);

  /// @dev Emitted when a token bridge is finalized
  event Claim(address indexed token, uint256 amount);

  /// @dev Emitted when token is withdrawn to the Aave Collector
  event WithdrawToCollector(address indexed token, uint256 amount);

  /// @dev The address of bridge contract on mainnet
  function MAINNET_BRIDGE() external view returns (address);

  /// @dev The address of bridge contract on sonic
  function SONIC_BRIDGE() external view returns (address);

  /**
   * @dev This function deposits token from Ethereum to Sonic
   * @notice Ethereum only. Function will revert if called from other network.
   * @param token The address of token to deposit
   * @param amount Amount of tokens to deposit
   */
  function deposit(address token, uint256 amount) external;

  /**
   * @dev This function deposits tokens from Ethereum to Sonic
   * @notice Ethereum only. Function will revert if called from other network.
   * @param tokens The addresses of token to deposit
   * @param amounts Amounts of tokens to deposit
   */
  function deposit(address[] memory tokens, uint256[] memory amounts) external;

  /**
   * @dev This function withdraws token from Sonic to Ethereum
   * @notice Sonic only. Function will revert if called from other network.
   * @param originalToken The address of original token to withdraw
   * @param amount Amount of tokens to withdraw
   */
  function withdraw(address originalToken, uint256 amount) external;

  /**
   * @dev This function withdraws tokens from Sonic to Ethereum
   * @notice Sonic only. Function will revert if called from other network.
   * @param originalTokens The addressese of original token to withdraw
   * @param amounts Amounts of tokens to withdraw
   */
  function withdraw(address[] memory originalTokens, uint256[] memory amounts) external;

  /**
   * @dev This function claims bridged tokens
   *      Burn proof is generated via CLI. Please see README.md
   * @param id The hash of deposit & claim transaction
   * @param token The address of token
   * @param amount Bridged amount
   * @param proof Burn proof generated via CLI.
   */
  function claim(uint256 id, address token, uint256 amount, bytes calldata proof) external;

  /**
   * @dev Withdraws token to Aave V3 Collector.
   * @param token The address of token to withdraw
   */
  function withdrawToCollector(address token) external;

  /// @dev Withdraws token to Aave V3 Collector.
  function withdrawEthToCollector() external;
}
