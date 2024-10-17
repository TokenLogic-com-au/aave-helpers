// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function getSwapFeePercentage() external view returns (uint256);

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
