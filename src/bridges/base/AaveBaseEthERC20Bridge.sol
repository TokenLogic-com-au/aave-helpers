// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {Rescuable} from 'solidity-utils/contracts/utils/Rescuable.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {ChainIds} from 'solidity-utils/contracts/utils/ChainHelpers.sol';

import {IAaveBaseEthERC20Bridge} from './IAaveBaseEthERC20Bridge.sol';
import {IStandardBridge} from './IStandardBridge.sol';

/**
 * @title AaveBaseEthERC20Bridge
 * @author efecarranza.eth
 * @notice Helper contract to bridge assets from Base to Ethereum Mainnet
 */
contract AaveBaseEthERC20Bridge is Ownable, Rescuable, IAaveBaseEthERC20Bridge {
  using SafeERC20 for IERC20;

  address public constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;
  uint256 private _nonce;

  /// @param _owner The owner of the contract upon deployment
  constructor(address _owner) {
    _transferOwnership(_owner);
  }

  /// @inheritdoc IAaveBaseEthERC20Bridge
  function bridge(address token, address l1Token, uint256 amount) external onlyOwner {
    if (block.chainid != ChainIds.BASE) revert InvalidChain();

    IERC20(token).forceApprove(L2_STANDARD_BRIDGE, amount);
    IStandardBridge(L2_STANDARD_BRIDGE).bridgeERC20To(
      token,
      l1Token,
      address(AaveV3Ethereum.COLLECTOR),
      amount,
      250000,
      abi.encodePacked(_nonce)
    );

    emit Bridge(token, l1Token, amount, address(AaveV3Ethereum.COLLECTOR), _nonce++);
  }

  /// @inheritdoc IAaveBaseEthERC20Bridge
  function nonce() external view returns (uint256) {
    return _nonce;
  }

  /// @inheritdoc Rescuable
  function whoCanRescue() public view override returns (address) {
    return owner();
  }
}
