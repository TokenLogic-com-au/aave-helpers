// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveWeethWithdrawer {
  /// @notice emitted when a new Withdrawal is requested
  /// @param amount the amount requested to be withdrawn
  /// @param requestId the respective request ID (or tokenId) to be used to finalize the withdrawal
  event StartedWithdrawal(uint256 amount, uint256 indexed requestId);

  /// @notice emitted when a new Withdrawal is requested
  /// @param amount the amount of WETH withdrawn to collector
  /// @param requestId the respective request ID (or tokenId) used to finalize the withdrawal
  event FinalizedWithdrawal(uint256 amount, uint256 indexed requestId);

  /// @notice Starts a new withdrawal
  /// @param amount an amount of weETH to be withdrawn
  function startWithdraw(uint256 amount) external;

  /// @notice Finalizes a withdrawal
  /// @param requestId the request ID (or tokenId)of the withdrawal to be finalized
  function finalizeWithdraw(uint256 requestId) external;
}

/// taken from: https://etherscan.io/address/0x02656fe285fac5d5c756c2f03c17277df9bac65b#code
interface ILiquidityPool {
  /// @notice request withdraw from pool and receive a WithdrawRequestNFT
  /// @dev Transfers the amount of eETH from msg.senders account to the WithdrawRequestNFT contract & mints an NFT to the msg.sender
  /// @param recipient address that will be issued the NFT
  /// @param amount requested amount to withdraw from contract
  /// @return uint256 requestId of the WithdrawRequestNFT
  function requestWithdraw(address recipient, uint256 amount) external returns (uint256);
}

/// taken from: https://etherscan.io/address/0x3ed97c79ded8894036da095b2e2f79f8080a9cd4#code
interface IWithdrawRequestNFT {
  /// @notice called by the NFT owner to claim their ETH
  /// @dev burns the NFT and transfers ETH from the liquidity pool to the owner minus any fee, withdraw request must be valid and finalized
  /// @param tokenId the id of the withdraw request and associated NFT
  function claimWithdraw(uint256 tokenId) external;
}

interface IWEETH {
  function unwrap(uint256 amount) external returns(uint256);
}

interface IWETH {
  function deposit() external payable;
}