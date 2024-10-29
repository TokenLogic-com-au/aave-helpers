// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {EthereumScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {IBalancerStrategyManager, BalancerV2WeightedPoolStrategyManager} from 'src/balancer-strategy-manager/BalancerV2WeightedPoolStrategyManager.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';

contract DeployBalancerV2WeightedPoolStrategyManager is EthereumScript {
  // https://etherscan.io/address/0xBA12222222228d8Ba445958a75a0704d566BF2C8
  address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

  function run() external broadcast {
    bytes32 salt = 'Balancer V2 Weighted Pool';

    IBalancerStrategyManager.TokenConfig[]
      memory tokens = new IBalancerStrategyManager.TokenConfig[](2);

    tokens[0] = IBalancerStrategyManager.TokenConfig({
      token: AaveV3EthereumAssets.wstETH_UNDERLYING,
      provider: 0x94A8518B76A3c45F5387B521695024379d43d715
    });
    tokens[1] = IBalancerStrategyManager.TokenConfig({
      token: AaveV3EthereumAssets.AAVE_UNDERLYING,
      provider: 0x94A8518B76A3c45F5387B521695024379d43d715
    });

    new BalancerV2WeightedPoolStrategyManager{salt: salt}(
      BALANCER_VAULT,
      tokens,
      // GovernanceV3Ethereum.EXECUTOR_LVL_1,
      0x94A8518B76A3c45F5387B521695024379d43d715,
      // MiscEthereum.PROTOCOL_GUARDIAN,
      0x94A8518B76A3c45F5387B521695024379d43d715,
      address(0)
    );
  }
}
