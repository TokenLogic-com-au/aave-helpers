// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {RescuableBase, IRescuableBase} from 'solidity-utils/contracts/utils/RescuableBase.sol';

import {IBalancerVault} from './balancer-v2/IBalancerVault.sol';
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

  /// @notice The Balancer Vault contract
  IBalancerVault public immutable VAULT;

  /// @notice The number of tokens in the pool

  /// @notice The address of the Hypernative service
  address public immutable HYPERNATIVE;

  /// @dev Mapping of token configurations (token to provider)
  mapping(address token => address provider) public override tokenProvider;

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
   * @param _tokenConfig The array of token configurations (address and provider).
   * @param _owner The owner of the contract.
   * @param _guardian The guardian of the contract.
   * @param _hypernative The Hypernative service address.
   */
  constructor(
    address _vault,
    TokenConfig[] memory _tokenConfig,
    address _owner,
    address _guardian,
    address _hypernative
  ) {
    VAULT = IBalancerVault(_vault);

    for (uint256 i = 0; i < _tokenConfig.length; ) {
      tokenProvider[_tokenConfig[i].token] = _tokenConfig[i].provider;

      emit TokenProviderUpdated(_tokenConfig[i].token, address(0), _tokenConfig[i].provider);

      unchecked {
        ++i;
      }
    }

    _transferOwnership(_owner);
    _updateGuardian(_guardian);
    HYPERNATIVE = _hypernative;
  }

  /// @inheritdoc IBalancerStrategyManager
  function setTokenProvider(address _token, address _provider) external onlyOwner {
    address oldProvider = tokenProvider[_token];
    tokenProvider[_token] = _provider;

    emit TokenProviderUpdated(_token, oldProvider, _provider);
  }

  /// @inheritdoc IBalancerStrategyManager
  function deposit(bytes32 _poolId, uint256[] calldata _tokenAmounts) external onlyOwnerOrGuardian {
    address[] memory assets;
    (assets, , ) = VAULT.getPoolTokens(_poolId);
    uint256 tokenCount = assets.length;
    (address poolAddress, ) = VAULT.getPool(_poolId);

    if (_tokenAmounts.length != tokenCount) {
      revert TokenCountMismatch();
    }

    for (uint256 i = 0; i < tokenCount; ) {
      uint256 currentBalance = IERC20(assets[i]).balanceOf(address(this));

      if (_tokenAmounts[i] > currentBalance) {
        revert InsufficientToken(assets[i], currentBalance);
      }

      unchecked {
        ++i;
      }
    }

    for (uint256 i = 0; i < tokenCount; ) {
      IERC20(assets[i]).safeIncreaseAllowance(address(VAULT), _tokenAmounts[i]);

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

    uint256 bptAmountBefore = IERC20(poolAddress).balanceOf(address(this));
    VAULT.joinPool(_poolId, address(this), address(this), request);
    uint256 bptAmountAfter = IERC20(poolAddress).balanceOf(address(this));

    emit TokenDeposit(_msgSender(), _poolId, _tokenAmounts, bptAmountAfter - bptAmountBefore);
  }

  /// @inheritdoc IBalancerStrategyManager
  function withdraw(
    bytes32 _poolId,
    uint256 bpt
  ) external onlyOwnerOrGuardian returns (uint256[] memory) {
    return _withdraw(_poolId, bpt);
  }

  /// @inheritdoc IBalancerStrategyManager
  function emergencyWithdraw(bytes32 _poolId) external onlyWithdrawable returns (uint256[] memory) {
    (address poolAddress, ) = VAULT.getPool(_poolId);

    return _withdraw(_poolId, IERC20(poolAddress).balanceOf(address(this)));
  }

  /**
   * @dev Internal function to withdraw tokens from the pool.
   * @param poolId The id of balancer pool to deposit
   * @param bptAmount The amount of BPT to burn.
   * @return tokenAmounts The amounts of each token withdrawn.
   */
  function _withdraw(
    bytes32 poolId,
    uint256 bptAmount
  ) internal returns (uint256[] memory tokenAmounts) {
    address[] memory assets;
    (assets, , ) = VAULT.getPoolTokens(poolId);
    uint256 tokenCount = assets.length;

    bytes memory userData = abi.encode(
      WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT,
      bptAmount
    );
    IBalancerVault.ExitPoolRequest memory request = IBalancerVault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: new uint256[](tokenCount),
      userData: userData,
      toInternalBalance: false
    });

    VAULT.exitPool(poolId, address(this), payable(address(this)), request);

    tokenAmounts = _sendTokensToProvider(assets);

    emit TokenWithdraw(_msgSender(), poolId, tokenAmounts, bptAmount);
  }

  /**
   * @dev Internal function to return the remaining tokens to their respective providers.
   * @param tokens The addresses of token to send
   * @return tokenAmounts The amounts of tokens returned to the providers.
   */
  function _sendTokensToProvider(address[] memory tokens) internal returns (uint256[] memory) {
    uint256 length = tokens.length;
    uint256[] memory tokenAmounts = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      tokenAmounts[i] = _sendTokenToProvider(IERC20(tokens[i]), tokenProvider[tokens[i]]);

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
