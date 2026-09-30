// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC1271} from 'openzeppelin-contracts/contracts/interfaces/IERC1271.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';

/**
 * @title AaveSwapperV2
 * @notice Helper contract to execute Aave DAO treasury swaps via CoW Protocol using EIP-1271.
 * @dev Direct EIP-1271 order signing with dynamic on-chain oracle verification utilizing GPv2VaultRelayer approvals.
 */
contract AaveSwapperV2 is IERC1271, OwnableWithGuardian, Rescuable {
  using SafeERC20 for IERC20;

  /// @notice EIP-1271 magic value returned upon successful verification
  bytes4 internal constant MAGICVALUE = 0x1626ba7e;

  /// @notice CoW Protocol GPv2VaultRelayer contract (same across all EVM chains)
  address public constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

  /// @notice CoW Protocol GPv2Settlement contract (same across all EVM chains)
  address public constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

  constructor(address initialOwner, address initialGuardian)
    OwnableWithGuardian(initialOwner, initialGuardian)
  {}

  /**
   * @notice EIP-1271 signature validation function called by CoW Protocol GPv2Settlement
   * @param orderDigest The EIP-712 digest of the proposed CoW order
   * @param signature Encoded order data and verification payload supplied by solver/order
   * @return magicValue 0x1626ba7e if valid, 0xffffffff (or revert) if invalid
   */
  function isValidSignature(
    bytes32 orderDigest,
    bytes calldata signature
  ) external view override returns (bytes4 magicValue) {
    // TODO: Implement order reconstruction, dynamic oracle price check, and appData validation
    return bytes4(0);
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return owner();
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(
    address
  ) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
    return type(uint256).max;
  }
}
