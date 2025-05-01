// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridge {
  function deposit(uint96 uid, address token, uint256 amount) external;
  function withdraw(uint96 uid, address token, uint256 amount) external;
  function claim(uint256 id, address token, uint256 amount, bytes calldata proof) external;
}
