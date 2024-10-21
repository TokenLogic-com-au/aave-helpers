// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IBalancerPool {
  /**
   * @dev Returns this Pool's ID, used when interacting with the Vault (to e.g. join the Pool or swap with it).
   */
  function getPoolId() external view returns (bytes32);

  /**
   * @dev Returns the current swap fee percentage as a 18 decimal fixed point number, so e.g. 1e17 corresponds to a
   * 10% swap fee.
   */
  function getSwapFeePercentage() external view returns (uint256);

  /**
   * @dev Returns the scaling factors of each of the Pool's tokens. This is an implementation detail that is typically
   * not relevant for outside parties, but which might be useful for some types of Pools.
   */
  function getScalingFactors() external view returns (uint256[] memory);

  function queryJoin(
    bytes32 poolId,
    address sender,
    address recipient,
    uint256[] memory balances,
    uint256 lastChangeBlock,
    uint256 protocolSwapFeePercentage,
    bytes memory userData
  ) external returns (uint256 bptOut, uint256[] memory amountsIn);

  function queryExit(
    bytes32 poolId,
    address sender,
    address recipient,
    uint256[] memory balances,
    uint256 lastChangeBlock,
    uint256 protocolSwapFeePercentage,
    bytes memory userData
  ) external returns (uint256 bptIn, uint256[] memory amountsOut);
}
