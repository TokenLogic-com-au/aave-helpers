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

/**
 * @title Balancer V2 Weighted Pool Strategy Manager
 * @author TokenLogic
 * @notice A contract to manage deposits and withdrawals into a Balancer V2 Weighted Pool.
 * @dev This contract uses the Balancer Vault to manage liquidity, using exact token amounts for BPT.
 */
contract BalancerV2WeightedPoolStrategyManager is
  IBalancerStrategyManager,
  OwnableWithGuardian,
  Rescuable
{
  using SafeERC20 for IERC20;

  /// @notice The Balancer pool ID associated with the strategy
  bytes32 public immutable POOL_ID;

  /// @notice The Balancer pool contract
  IBalancerPool public immutable POOL;

  /// @notice The Balancer Vault contract
  IBalancerVault public immutable VAULT;

  /// @notice The number of tokens in the pool
  uint256 public immutable TOKEN_COUNT;

  /// @notice The address of the Hypernative service
  address public immutable HYPERNATIVE;

  /// @dev Mapping of token configurations (index to TokenConfig)
  mapping(uint256 id => TokenConfig config) private tokenConfig;

  /// @dev Restricts access to only the owner, guardian, or Hypernative address.
  modifier onlyWithdrawable() {
    if (_msgSender() != owner() && _msgSender() != guardian() && _msgSender() != HYPERNATIVE) {
      revert Unauthorized();
    }
    _;
  }

  /**
   * @notice Constructor to initialize the contract.
   * @param _vault The address of the Balancer Vault.
   * @param _poolId The Balancer pool ID.
   * @param _tokenConfig The array of token configurations (address and provider).
   * @param _owner The owner of the contract.
   * @param _guardian The guardian of the contract.
   * @param _hypernative The Hypernative service address.
   */
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

    address[] memory actualTokens;
    (actualTokens, , ) = VAULT.getPoolTokens(_poolId);

    TOKEN_COUNT = actualTokens.length;

    if (_tokenConfig.length != TOKEN_COUNT) {
      revert TokenCountMismatch();
    }

    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      if (actualTokens[i] != _tokenConfig[i].token) {
        revert TokenMismatch();
      }

      tokenConfig[i] = _tokenConfig[i];

      emit TokenProviderUpdated(i, _tokenConfig[i].token, address(0), _tokenConfig[i].provider);

      unchecked {
        ++i;
      }
    }

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
    HYPERNATIVE = _hypernative;
  }

  /// @inheritdoc IBalancerStrategyManager
  function setTokenProvider(uint256 _id, address _provider) external onlyOwner {
    if (_id >= TOKEN_COUNT) {
      revert TokenCountMismatch();
    }

    address oldProvider = tokenConfig[_id].provider;
    tokenConfig[_id].provider = _provider;

    emit TokenProviderUpdated(_id, tokenConfig[_id].token, oldProvider, _provider);
  }

  /// @inheritdoc IBalancerStrategyManager
  function deposit(uint256[] calldata _tokenAmounts) external onlyOwnerOrGuardian {
    if (_tokenAmounts.length != TOKEN_COUNT) {
      revert TokenCountMismatch();
    }

    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      uint256 currentBalance = IERC20(tokenConfig[i].token).balanceOf(address(this));

      if (_tokenAmounts[i] > currentBalance) {
        revert InsufficientToken(tokenConfig[i].token, currentBalance);
      }

      unchecked {
        ++i;
      }
    }

    IAsset[] memory assets = new IAsset[](TOKEN_COUNT);
    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      IERC20(tokenConfig[i].token).safeIncreaseAllowance(address(VAULT), _tokenAmounts[i]);
      assets[i] = IAsset(tokenConfig[i].token);

      unchecked {
        ++i;
      }
    }

    bytes memory userData = abi.encode(
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

    uint256 bptAmountBefore = IERC20(address(POOL)).balanceOf(address(this));
    VAULT.joinPool(POOL_ID, address(this), address(this), request);
    uint256 bptAmountAfter = IERC20(address(POOL)).balanceOf(address(this));

    emit TokenDeposit(_msgSender(), _tokenAmounts, bptAmountAfter - bptAmountBefore);
  }

  /// @inheritdoc IBalancerStrategyManager
  function withdraw(uint256 bpt) external onlyOwnerOrGuardian returns (uint256[] memory) {
    return _withdraw(bpt);
  }

  /// @inheritdoc IBalancerStrategyManager
  function emergencyWithdraw() external onlyWithdrawable returns (uint256[] memory) {
    return _withdraw(IERC20(address(POOL)).balanceOf(address(this)));
  }

  /// @inheritdoc IBalancerStrategyManager
  function getTokenConfig(uint256 id) external view returns (TokenConfig memory) {
    return tokenConfig[id];
  }

  /**
   * @dev Internal function to withdraw tokens from the pool.
   * @param bptAmount The amount of BPT to burn.
   * @return tokenAmounts The amounts of each token withdrawn.
   */
  function _withdraw(uint256 bptAmount) internal returns (uint256[] memory tokenAmounts) {
    uint256[] memory minAmountsOut = new uint256[](TOKEN_COUNT);
    IAsset[] memory assets = new IAsset[](TOKEN_COUNT);
    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      assets[i] = IAsset(tokenConfig[i].token);

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

    tokenAmounts = _sendTokensToProvider();

    emit TokenWithdraw(_msgSender(), tokenAmounts, bptAmount);
  }

  /**
   * @dev Internal function to return the remaining tokens to their respective providers.
   * @return tokenAmounts The amounts of tokens returned to the providers.
   */
  function _sendTokensToProvider() internal returns (uint256[] memory) {
    uint256[] memory tokenAmounts = new uint256[](TOKEN_COUNT);

    for (uint256 i = 0; i < TOKEN_COUNT; ) {
      tokenAmounts[i] = _sendTokenToProvider(IERC20(tokenConfig[i].token), tokenConfig[i].provider);

      unchecked {
        ++i;
      }
    }

    return tokenAmounts;
  }

  /**
   * @dev Internal function to return the remaining balance of a token to its provider.
   * @param token The IERC20 token contract.
   * @param provider The address of the token provider.
   * @return tokenAmount The amount of tokens returned.
   */
  function _sendTokenToProvider(
    IERC20 token,
    address provider
  ) internal returns (uint256 tokenAmount) {
    tokenAmount = token.balanceOf(address(this));

    if (tokenAmount > 0) {
      token.forceApprove(address(POOL), 0);
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
}
