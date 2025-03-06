// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title IAaveSonicEthERC20Bridge
/// @author TokenLogic
/// @notice Interface for AaveSonicEthERC20Bridge
interface IAaveSonicEthERC20Bridge {
  /// @dev The called method is not available on this chain
  error InvalidChain();

  /// @dev Emitted when a bridge is initiated
  event Bridge(address indexed token, uint256 amount);

  /// @dev Emitted when the bridge transaction is confirmed
  event ConfirmExit(bytes proof);

  /// @dev Emitted when a token bridge is finalized
  event Claim(address indexed token, uint256 amount);

  /// @dev Emitted when token is withdrawn to the Aave Collector
  event WithdrawToCollector(address token, uint256 amount);

  /// @dev The address of bridge contract
  function BRIDGE() external view returns (address);

  /**
   * @dev This function deposits token from Ethereum to Sonic
   * @notice Ethereum only. Function will revert if called from other network.
   * @param token The address of token to deposit
   * @param amount Amount of tokens to deposit
   */
  function deposit(address token, uint256 amount) external;

  /**
   * @dev This function withdraws token from Sonic to Ethereum
   * @notice Sonic only. Function will revert if called from other network.
   * @param token The address of token to deposit
   * @param amount Amount of tokens to deposit
   */
  function withdraw(address token, uint256 amount) external;

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
}
