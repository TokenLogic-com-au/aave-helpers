// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IBalancerPool} from './balancer-v2/IBalancerPool.sol';
import {IBalancerVault, IAsset} from './balancer-v2/IBalancerVault.sol';
import {WeightedPoolUserData} from './balancer-v2/WeightedPoolUserData.sol';
import {IBalancerStrategyManager} from './IBalancerStrategyManager.sol';

contract BalancerV2WeightedPoolStrategyManager is
  IBalancerStrategyManager,
  OwnableWithGuardian,
  Rescuable
{
  using SafeERC20 for IERC20;

  struct TokenConfig {
    address token;
    address provider;
  }

  bytes32 public immutable POOL_ID;
  IBalancerPool public immutable POOL;
  IBalancerVault public immutable VAULT;
  uint256 public immutable TOKEN_COUNT;
  address public immutable HYPERNATIVE;

  mapping(uint256 id => TokenConfig config) public tokenConfig;

  modifier onlyWithdrawable() {
    if (_msgSender() != owner() && _msgSender() != guardian() && _msgSender() != HYPERNATIVE) {
      revert AccessForbidden();
    }
    _;
  }

  constructor(
    address _vault,
    bytes32 _poolId,
    TokenConfig[] memory _tokenConfig,
    address _owner,
    address _guardian,
    address _hypernative
  ) {
    VAULT = IBalancerVault(_vault);
    POOL_ID = _poolId;

    (address poolAddress, ) = VAULT.getPool(_poolId);
    POOL = IBalancerPool(poolAddress);

    address[] memory actuallTokens;
    (actuallTokens, , ) = VAULT.getPoolTokens(_poolId);

    TOKEN_COUNT = _tokenConfig.length;
    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      if (actuallTokens[i] != _tokenConfig[i].token) {
        revert TokenMismatch();
      }

      tokenConfig[i] = _tokenConfig[i];

      unchecked {
        ++i;
      }
    }

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
    HYPERNATIVE = _hypernative;
  }

  /// @inheritdoc IBalancerStrategyManager
  function deposit(uint256[] calldata _tokenAmounts) external onlyOwnerOrGuardian {
    if (_tokenAmounts.length != TOKEN_COUNT) {
      revert TokenCountMismatch();
    }

    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      IERC20 token = IERC20(tokenConfig[i].token);

      if (_tokenAmounts[i] > token.balanceOf(address(this))) {
        revert InsufficientToken(address(token));
      }

      unchecked {
        ++i;
      }
    }

    bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT);

    IAsset[] memory assets = new IAsset[](TOKEN_COUNT);
    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      IERC20(tokenConfig[i].token).safeIncreaseAllowance(address(VAULT), _tokenAmounts[i]);
      assets[i] = IAsset(tokenConfig[i].token);

      unchecked {
        ++i;
      }
    }

    userData = abi.encode(
      WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
      _tokenAmounts,
      0
    );

    IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: _tokenAmounts,
      userData: userData,
      fromInternalBalance: false
    });

    VAULT.joinPool(POOL_ID, address(this), address(this), request);
  }

  /// @inheritdoc IBalancerStrategyManager
  function withdraw(uint256 bpt) external onlyOwnerOrGuardian returns (uint256[] memory) {
    return _withdraw(bpt);
  }

  /// @inheritdoc IBalancerStrategyManager
  function emergencyWithdraw() external onlyWithdrawable returns (uint256[] memory) {
    uint256 bptAmount = IERC20(address(POOL)).balanceOf(address(this));

    return _withdraw(bptAmount);
  }

  /// @dev withdraws token from pool
  function _withdraw(uint256 bptAmount) internal returns (uint256[] memory tokenAmounts) {
    // IERC20(address(POOL)).safeIncreaseAllowance(address(VAULT), bptAmount);

    uint256[] memory minAmountsOut = new uint256[](TOKEN_COUNT);
    IAsset[] memory assets = new IAsset[](TOKEN_COUNT);
    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      assets[i] = IAsset(tokenConfig[i].token);
      minAmountsOut[i] = 0;

      unchecked {
        ++i;
      }
    }

    bytes memory userData = abi.encode(
      WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT,
      bptAmount
    );
    IBalancerVault.ExitPoolRequest memory request = IBalancerVault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: minAmountsOut,
      userData: userData,
      toInternalBalance: false
    });

    VAULT.exitPool(POOL_ID, address(this), payable(address(this)), request);

    tokenAmounts = _backTokens();
  }

  /// @dev send back remaining tokens to provider
  function _backTokens() internal returns (uint256[] memory) {
    uint256[] memory tokenAmounts = new uint256[](TOKEN_COUNT);

    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      tokenAmounts[i] = _backToken(IERC20(tokenConfig[i].token), tokenConfig[i].provider);

      unchecked {
        ++i;
      }
    }

    return tokenAmounts;
  }

  /// @dev send back remaining tokens to provider
  function _backToken(IERC20 token, address provider) internal returns (uint256 tokenAmount) {
    tokenAmount = token.balanceOf(address(this));

    if (tokenAmount > 0) {
      token.approve(address(POOL), 0);
      token.transfer(provider, tokenAmount);
    }
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

  error TokenMismatch();
  error TokenCountMismatch();
  error InsufficientToken(address token);
  error AccessForbidden();
}
