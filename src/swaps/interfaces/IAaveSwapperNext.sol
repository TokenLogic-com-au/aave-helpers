// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC1271} from 'openzeppelin-contracts/contracts/interfaces/IERC1271.sol';

interface IAaveSwapperNext is IERC1271 {
  /// @notice Parameters of a market swap
  /// @param fromToken Address of the token to swap from
  /// @param toToken Address of the token to swap to
  /// @param fromOracle Oracle to use for price validation for fromToken
  /// @param toOracle Oracle to use for price validation for toToken
  /// @param recipient Address receiving the swap
  /// @param amount Amount of fromToken to swap
  /// @param slippage The allowed slippage for the swap, where 100_00 is equal to 100%
  /// @param salt Salt of the conditional order, makes otherwise identical swaps unique
  struct SwapParams {
    address fromToken;
    address toToken;
    address fromOracle;
    address toOracle;
    address recipient;
    uint256 amount;
    uint256 slippage;
    bytes32 salt;
  }

  /// @dev Emitted when a swap is created on ComposableCoW
  /// @param orderHash Hash of the conditional order on ComposableCoW
  /// @param fromToken Address of the token to swap from
  /// @param toToken Address of the token to swap to
  /// @param fromOracle Oracle to use for price validation for fromToken
  /// @param toOracle Oracle to use for price validation for toToken
  /// @param amount Amount of fromToken to swap
  /// @param recipient Address receiving the swap
  /// @param slippage The allowed slippage for the swap
  event SwapRequested(
    bytes32 orderHash,
    address indexed fromToken,
    address indexed toToken,
    address fromOracle,
    address toOracle,
    uint256 amount,
    address indexed recipient,
    uint256 slippage
  );

  /// @dev Emitted when a swap is canceled
  /// @param orderHash Hash of the conditional order on ComposableCoW
  /// @param fromToken The token to swap from
  /// @param toToken The token to swap to
  /// @param amount Amount of fromToken returned to the Collector
  event SwapCanceled(
    bytes32 indexed orderHash,
    address indexed fromToken,
    address indexed toToken,
    uint256 amount
  );

  /// @dev Provided address cannot be the zero-address
  error Invalid0xAddress();

  /// @dev Amount has to be greater than zero
  error InvalidAmount();

  /// @dev Recipient cannot be the zero-address
  error InvalidRecipient();

  /// @dev Slippage is above MAX_SLIPPAGE
  error InvalidSlippage();

  /// @dev Oracle has not be set
  error OracleNotSet();

  /// @dev A swap of fromToken is already pending; only one pending swap per fromToken is allowed
  error SwapAlreadyPending();

  /// @dev The swap is not an authorized order on ComposableCoW
  error SwapNotFound();

  /// @notice Returns the oracle market order handler
  function MARKET_ORDER_HANDLER() external view returns (address);

  /// @notice Returns the GPv2VaultRelayer that pulls the sold tokens
  function VAULT_RELAYER() external view returns (address);

  /// @notice Returns the Collector, which receives the fromToken back when a swap is canceled
  function COLLECTOR() external view returns (address);

  /// @notice Returns the appData pinned on every order
  function APP_DATA() external view returns (bytes32);

  /// @notice Returns the maximum allowed slippage, where 100_00 is equal to 100%
  function MAX_SLIPPAGE() external view returns (uint256);

  /// @notice Creates a market swap as a conditional order on ComposableCoW
  /// @dev fromToken must be held by this contract before the call. Approves the vault relayer for exactly
  ///      amount; the relayer allowance is the swap's fill state, so only one swap per fromToken may be pending
  /// @param params Swap parameters
  /// @return orderHash Hash of the conditional order on ComposableCoW
  function swap(SwapParams calldata params) external returns (bytes32 orderHash);

  /// @notice Cancels a swap and returns its unfilled fromToken to the Collector
  /// @dev Refunds the remaining relayer allowance (amount, or 0 if the order was filled), then zeroes it
  /// @param params Swap parameters the swap was created with
  function cancelSwap(SwapParams calldata params) external;

  /// @notice Returns the expected amount out in token to swap to, before slippage
  /// @param fromToken Address of the token to swap from
  /// @param toToken Address of the token to swap to
  /// @param fromOracle Oracle to use for price validation for fromToken
  /// @param toOracle Oracle to use for price validation for toToken
  /// @param amount Amount of fromToken to swap
  function getExpectedOut(
    address fromToken,
    address toToken,
    address fromOracle,
    address toOracle,
    uint256 amount
  ) external view returns (uint256);
}
