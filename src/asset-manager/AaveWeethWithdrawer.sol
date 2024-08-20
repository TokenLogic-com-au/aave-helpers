// SPDX-License-Identifier: MIT
/*
   _      ΞΞΞΞ      _
  /_;-.__ / _\  _.-;_\
     `-._`'`_/'`.-'
         `\   /`
          |  /
         /-.(
         \_._\
          \ \`;
           > |/
          / //
          |//
          \(\
           ``
     defijesus.eth
*/
pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';
import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';
import {Rescuable721, Rescuable} from 'solidity-utils/contracts/utils/Rescuable721.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {IAaveWeethWithdrawer, ILiquidityPool, IWithdrawRequestNFT, IWETH, IWEETH} from './interfaces/IAaveWeethWithdrawer.sol';

/**
 * @title AaveWeethWithdrawer
 * @author defijesus.eth
 * @notice Helper contract to natively withdraw wstETH to the collector
 */
contract AaveWeethWithdrawer is Initializable, OwnableWithGuardian, Rescuable721, IAaveWeethWithdrawer {
  using SafeERC20 for IERC20;

  /// https://etherscan.io/address/0x308861a430be4cce5502d0a12724771fc6daf216
  ILiquidityPool public constant WEETH_LIQUIDITY_POOL =
    ILiquidityPool(0x308861A430be4cce5502d0A12724771Fc6DaF216);

  /// https://etherscan.io/address/0x7d5706f6ef3f89b3951e23e557cdfbc3239d4e2c
  IWithdrawRequestNFT public constant WITHDRAW_REQUEST_NFT =
    IWithdrawRequestNFT(0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c);

  address public constant EETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;

  function initialize() external initializer {
    _transferOwnership(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    _updateGuardian(0x2cc1ADE245020FC5AAE66Ad443e1F66e01c54Df1);
    IERC20(EETH).approve(
      address(WEETH_LIQUIDITY_POOL),
      type(uint256).max
    );
  }

  /// @inheritdoc IAaveWeethWithdrawer
  function startWithdraw(uint256 amount) external onlyOwnerOrGuardian {
    uint256 eethAmount = IWEETH(AaveV3EthereumAssets.weETH_UNDERLYING).unwrap(amount);
    uint256 requestId = WEETH_LIQUIDITY_POOL.requestWithdraw(address(this), eethAmount);
    emit StartedWithdrawal(eethAmount, requestId);
  }

  /// @inheritdoc IAaveWeethWithdrawer
  function finalizeWithdraw(uint256 requestId) external onlyOwnerOrGuardian {
    WITHDRAW_REQUEST_NFT.claimWithdraw(requestId);

    uint256 ethBalance = address(this).balance;

    IWETH(AaveV3EthereumAssets.WETH_UNDERLYING).deposit{value: ethBalance}();

    IERC20(AaveV3EthereumAssets.WETH_UNDERLYING).transfer(
      address(AaveV3Ethereum.COLLECTOR),
      ethBalance
    );

    emit FinalizedWithdrawal(ethBalance, requestId);
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return owner();
  }

  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns(bytes4) {
    return this.onERC721Received.selector;
  }

  fallback() external payable {}
  receive() external payable {}
}
