// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {IRescuable721} from 'solidity-utils/contracts/utils/interfaces/IRescuable721.sol';
import {PermissionlessRescuable, IPermissionlessRescuable} from 'solidity-utils/contracts/utils/PermissionlessRescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';
import {ChainIds} from 'solidity-utils/contracts/utils/ChainHelpers.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Sonic} from 'aave-address-book/AaveV3Sonic.sol';

import {IBridge} from './interfaces/IBridge.sol';
import {ITokenPairs} from './interfaces/ITokenPairs.sol';
import {IBridgedAdapter} from './interfaces/IBridgedAdapter.sol';
import {IAaveSonicEthERC20Bridge} from './IAaveSonicEthERC20Bridge.sol';

/// @title AaveSonicEthERC20Bridge
/// @author TokenLogic
/// @notice Interface for AaveSonicEthERC20Bridge
contract AaveSonicEthERC20Bridge is
  IAaveSonicEthERC20Bridge,
  OwnableWithGuardian,
  PermissionlessRescuable
{
  using SafeERC20 for IERC20;

  // https://etherscan.io/address/0xa1E2481a9CD0Cb0447EeB1cbc26F1b3fff3bec20
  address public constant MAINNET_BRIDGE = 0xa1E2481a9CD0Cb0447EeB1cbc26F1b3fff3bec20;
  // https://sonicscan.org/address/0x9Ef7629F9B930168b76283AdD7120777b3c895b3
  address public constant SONIC_BRIDGE = 0x9Ef7629F9B930168b76283AdD7120777b3c895b3;
  // https://sonicscan.org/address/0x134E4c207aD5A13549DE1eBF8D43c1f49b00ba94
  address public constant SONIC_TOKEN_PAIR = 0x134E4c207aD5A13549DE1eBF8D43c1f49b00ba94;

  constructor(address owner, address guardian) OwnableWithGuardian(owner, guardian) {}

  /// @inheritdoc IAaveSonicEthERC20Bridge
  function deposit(address token, uint256 amount) external onlyOwnerOrGuardian {
    if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

    IERC20(token).approve(MAINNET_BRIDGE, amount);
    IBridge(MAINNET_BRIDGE).deposit(uint96(block.timestamp), token, amount);

    emit Bridge(token, amount);
  }

  /// @inheritdoc IAaveSonicEthERC20Bridge
  function withdraw(address originalToken, uint256 amount) external onlyOwnerOrGuardian {
    if (block.chainid != ChainIds.SONIC) revert InvalidChain();

    address mintedTokenAdapter = ITokenPairs(SONIC_TOKEN_PAIR).originalToMintedTerminable(
      originalToken
    );
    if (mintedTokenAdapter == address(0)) revert InvalidToken();

    address mintedToken = IBridgedAdapter(mintedTokenAdapter).token();
    IERC20(mintedToken).approve(mintedTokenAdapter, amount);
    IBridge(SONIC_BRIDGE).withdraw(uint96(block.timestamp), originalToken, amount);

    emit Bridge(originalToken, amount);
  }

  /// @inheritdoc IAaveSonicEthERC20Bridge
  function claim(uint256 id, address token, uint256 amount, bytes calldata proof) external {
    if (block.chainid == ChainIds.MAINNET) {
      IBridge(MAINNET_BRIDGE).claim(id, token, amount, proof);
    } else if (block.chainid == ChainIds.SONIC) {
      IBridge(SONIC_BRIDGE).claim(id, token, amount, proof);
    } else {
      revert InvalidChain();
    }

    emit Claim(token, amount);
  }

  /// @inheritdoc IAaveSonicEthERC20Bridge
  function withdrawToCollector(address token) external {
    uint256 balance = IERC20(token).balanceOf(address(this));

    if (block.chainid == ChainIds.MAINNET) {
      IERC20(token).safeTransfer(address(AaveV3Ethereum.COLLECTOR), balance);
    } else if (block.chainid == ChainIds.SONIC) {
      IERC20(token).safeTransfer(address(AaveV3Sonic.COLLECTOR), balance);
    } else {
      revert InvalidChain();
    }
    emit WithdrawToCollector(token, balance);
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(
    address erc20Token
  ) public view override(IRescuableBase, RescuableBase) returns (uint256) {
    return type(uint256).max;
  }

  /// @inheritdoc IPermissionlessRescuable
  function whoShouldReceiveFunds() public view override returns (address) {
    return address(AaveV3Ethereum.COLLECTOR);
  }
}
