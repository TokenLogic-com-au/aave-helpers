// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBridgedAdapter {
  /// @return returns token address of adapter
  function token() external returns (address);
}
