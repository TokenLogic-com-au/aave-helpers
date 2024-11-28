// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {ICollector, CollectorUtils as CU} from '../CollectorUtils.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV2Ethereum, AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {IPool, DataTypes as DataTypesV3} from 'aave-address-book/AaveV3.sol';
import {ILendingPool, DataTypes as DataTypesV2} from 'aave-address-book/AaveV2.sol';
import {AaveSwapper} from '../swaps/AaveSwapper.sol';
import {AggregatorInterface} from './AggregatorInterface.sol';
import {IFinanceSteward} from './IFinanceSteward.sol';

/**
 * @title FinanceSteward
 * @author luigy-lemon  (Karpatkey)
 * @author efecarranza  (Tokenlogic)
 * @notice Helper contract that enables a Guardian to execute permissioned actions on the Aave Collector
 */
contract FinanceSteward is OwnableWithGuardian, IFinanceSteward {
  using DataTypesV2 for DataTypesV2.ReserveData;
  using DataTypesV3 for DataTypesV3.ReserveDataLegacy;

  using CU for ICollector;
  using CU for CU.IOInput;
  using CU for CU.CreateStreamInput;
  using CU for CU.SwapInput;

  error InvalidZeroAmount();
  error UnrecognizedReceiver();
  error ExceedsBalance();
  error ExceedsBudget();
  error UnrecognizedToken();
  error MissingPriceFeed();
  error PriceFeedFailure();
  error InvalidDate();
  error MinimumBalanceShield();

  ILendingPool public immutable POOLV2 = AaveV2Ethereum.POOL;
  IPool public immutable POOLV3 = AaveV3Ethereum.POOL;
  ICollector public immutable COLLECTOR = AaveV3Ethereum.COLLECTOR;

  AaveSwapper public immutable SWAPPER = AaveSwapper(MiscEthereum.AAVE_SWAPPER);
  address public immutable MILKMAN = 0x11C76AD590ABDFFCD980afEC9ad951B160F02797;
  address public immutable PRICE_CHECKER = 0xe80a1C615F75AFF7Ed8F08c9F21f9d00982D666c;

  mapping(address => bool) public transferApprovedReceiver;
  mapping(address => bool) public swapApprovedToken;
  mapping(address => address) public priceOracle;
  mapping(address => uint256) public tokenBudget;
  mapping(address => uint256) public minTokenBalance;
  uint256 public MAX_SLIPPAGE = 1000; // 10%
  uint256 public SLIPPAGE;

  constructor(address _owner, address _guardian) {
    _transferOwnership(_owner);
    _updateGuardian(_guardian);
    _updateSlippage(150);
  }

  /// Steward Actions

  /// @inheritdoc IFinanceSteward
  function depositV3(address reserve, uint256 amount) external onlyOwnerOrGuardian {
    CU.IOInput memory depositData = CU.IOInput(address(POOLV3), address(reserve), amount);
    CU.depositToV3(COLLECTOR, depositData);
  }

  /// @inheritdoc IFinanceSteward
  function migrateV2toV3(address reserve, uint256 amount) external onlyOwnerOrGuardian {
    if (amount == 0) {
      revert InvalidZeroAmount();
    }
    DataTypesV2.ReserveData memory reserveData = POOLV2.getReserveData(reserve);

    address atoken = reserveData.aTokenAddress;
    if (minTokenBalance[atoken] > 0) {
      uint256 currentBalance = IERC20(atoken).balanceOf(address(COLLECTOR));
      if (currentBalance - amount < minTokenBalance[atoken]) {
        revert MinimumBalanceShield();
      }
    }

    CU.IOInput memory withdrawData = CU.IOInput(address(POOLV2), address(reserve), amount);

    uint256 withdrawAmount = CU.withdrawFromV2(COLLECTOR, withdrawData, address(this));

    CU.IOInput memory depositData = CU.IOInput(address(POOLV3), address(reserve), withdrawAmount);
    CU.depositToV3(COLLECTOR, depositData);
  }

  /// @inheritdoc IFinanceSteward
  function withdrawV2andSwap(
    address reserve,
    uint256 amount,
    address buyToken
  ) external onlyOwnerOrGuardian {
    DataTypesV2.ReserveData memory reserveData = POOLV2.getReserveData(reserve);

    address atoken = reserveData.aTokenAddress;
    if (minTokenBalance[atoken] > 0) {
      uint256 currentBalance = IERC20(atoken).balanceOf(address(COLLECTOR));
      if (currentBalance - amount < minTokenBalance[atoken]) {
        revert MinimumBalanceShield();
      }
    }

    _validateSwap(reserve, amount, buyToken);

    CU.IOInput memory withdrawData = CU.IOInput(address(POOLV2), address(reserve), amount);

    uint256 withdrawAmount = CU.withdrawFromV2(COLLECTOR, withdrawData, address(this));

    CU.SwapInput memory swapData = CU.SwapInput(
      MILKMAN,
      PRICE_CHECKER,
      reserve,
      buyToken,
      priceOracle[reserve],
      priceOracle[buyToken],
      withdrawAmount,
      SLIPPAGE
    );

    CU.swap(COLLECTOR, address(SWAPPER), swapData);
  }

  /// @inheritdoc IFinanceSteward
  function withdrawV3andSwap(
    address reserve,
    uint256 amount,
    address buyToken
  ) external onlyOwnerOrGuardian {
    DataTypesV3.ReserveDataLegacy memory reserveData = POOLV3.getReserveData(reserve);
    address atoken = reserveData.aTokenAddress;
    if (minTokenBalance[atoken] > 0) {
      uint256 currentBalance = IERC20(atoken).balanceOf(address(COLLECTOR));
      if (currentBalance - amount < minTokenBalance[atoken]) {
        revert MinimumBalanceShield();
      }
    }

    _validateSwap(reserve, amount, buyToken);

    CU.IOInput memory withdrawData = CU.IOInput(address(POOLV3), address(reserve), amount);

    uint256 withdrawAmount = CU.withdrawFromV3(COLLECTOR, withdrawData, address(this));

    CU.SwapInput memory swapData = CU.SwapInput(
      MILKMAN,
      PRICE_CHECKER,
      reserve,
      buyToken,
      priceOracle[reserve],
      priceOracle[buyToken],
      withdrawAmount,
      SLIPPAGE
    );

    CU.swap(COLLECTOR, address(SWAPPER), swapData);
  }

  /// @inheritdoc IFinanceSteward
  function tokenSwap(
    address sellToken,
    uint256 amount,
    address buyToken
  ) external onlyOwnerOrGuardian {
    if (minTokenBalance[sellToken] > 0) {
      uint256 currentBalance = IERC20(sellToken).balanceOf(address(COLLECTOR));
      if (currentBalance - amount < minTokenBalance[sellToken]) {
        revert MinimumBalanceShield();
      }
    }

    _validateSwap(sellToken, amount, buyToken);

    CU.SwapInput memory swapData = CU.SwapInput(
      MILKMAN,
      PRICE_CHECKER,
      sellToken,
      buyToken,
      priceOracle[sellToken],
      priceOracle[buyToken],
      amount,
      SLIPPAGE
    );

    CU.swap(COLLECTOR, address(SWAPPER), swapData);
  }

  // Controlled Actions

  /// @inheritdoc IFinanceSteward
  function approve(address token, address to, uint256 amount) external onlyOwnerOrGuardian {
    _validateTransfer(token, to, amount);
    COLLECTOR.approve(token, to, amount);
  }

  /// @inheritdoc IFinanceSteward
  function transfer(address token, address to, uint256 amount) external onlyOwnerOrGuardian {
    _validateTransfer(token, to, amount);
    COLLECTOR.transfer(token, to, amount);
  }

  /// @inheritdoc IFinanceSteward
  function createStream(address to, StreamData memory stream) external onlyOwnerOrGuardian {
    if (stream.start < block.timestamp || stream.end <= stream.start) {
      revert InvalidDate();
    }

    _validateTransfer(stream.token, to, stream.amount);

    uint256 duration = stream.end - stream.start;

    CU.CreateStreamInput memory utilsData = CU.CreateStreamInput(
      stream.token,
      to,
      stream.amount,
      stream.start,
      duration
    );

    CU.stream(COLLECTOR, utilsData);
  }

  // Not sure if we want this functionality
  function cancelStream(uint256 streamId) external onlyOwnerOrGuardian {
    COLLECTOR.cancelStream(streamId);
  }

  function updateSlippage(uint256 slippage) external onlyOwnerOrGuardian {
    _updateSlippage(slippage);
  }

  /// DAO Actions

  /// @inheritdoc IFinanceSteward
  function increaseBudget(address token, uint256 amount) external onlyOwner {
    uint256 currentBudget = tokenBudget[token];
    _updateBudget(token, currentBudget + amount);
  }

  /// @inheritdoc IFinanceSteward
  function decreaseBudget(address token, uint256 amount) external onlyOwner {
    uint256 currentBudget = tokenBudget[token];
    if (amount > currentBudget) {
      _updateBudget(token, 0);
    } else {
      _updateBudget(token, currentBudget - amount);
    }
  }

  /// @inheritdoc IFinanceSteward
  function setSwappableToken(address token, address priceFeedUSD) external onlyOwner {
    if (priceFeedUSD == address(0)) revert MissingPriceFeed();

    swapApprovedToken[token] = true;
    priceOracle[token] = priceFeedUSD;

    // Validate oracle has necessary functions
    AggregatorInterface(priceFeedUSD).decimals();
    AggregatorInterface(priceFeedUSD).latestAnswer();

    emit SwapApprovedToken(token, priceFeedUSD);
  }

  /// @inheritdoc IFinanceSteward
  function setWhitelistedReceiver(address to) external onlyOwner {
    transferApprovedReceiver[to] = true;
    emit ReceiverWhitelisted(to);
  }

  /// @inheritdoc IFinanceSteward
  function setMinimumBalanceShield(address token, uint256 amount) external onlyOwner {
    minTokenBalance[token] = amount;
    emit MinimumTokenBalanceUpdated(token, amount);
  }

  /// Logic

  function _validateTransfer(address token, address to, uint256 amount) internal {
    if (transferApprovedReceiver[to] == false) {
      revert UnrecognizedReceiver();
    }

    uint256 currentBalance = IERC20(token).balanceOf(address(COLLECTOR));
    if (currentBalance < amount) {
      revert ExceedsBalance();
    }
    if (minTokenBalance[token] > 0) {
      if (currentBalance - amount < minTokenBalance[token]) {
        revert MinimumBalanceShield();
      }
    }

    uint256 currentBudget = tokenBudget[token];
    if (currentBudget < amount) {
      revert ExceedsBudget();
    }
    _updateBudget(token, currentBudget - amount);
  }

  function _validateSwap(address sellToken, uint256 amountIn, address buyToken) internal view {
    if (amountIn == 0) revert InvalidZeroAmount();

    if (!swapApprovedToken[sellToken] || !swapApprovedToken[buyToken]) {
      revert UnrecognizedToken();
    }

    if (
      AggregatorInterface(priceOracle[buyToken]).latestAnswer() == 0 ||
      AggregatorInterface(priceOracle[sellToken]).latestAnswer() == 0
    ) {
      revert PriceFeedFailure();
    }
  }

  function _updateBudget(address token, uint256 newAmount) internal {
    tokenBudget[token] = newAmount;
    emit BudgetUpdate(token, newAmount);
  }

  function _updateSlippage(uint256 _slippage) internal {
    if (_slippage > MAX_SLIPPAGE) {
      _slippage = MAX_SLIPPAGE;
    }
    SLIPPAGE = _slippage;
  }
}
