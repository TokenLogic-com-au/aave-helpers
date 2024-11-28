// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {ArbitrumScript, EthereumScript, OptimismScript, PolygonScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveArbEthERC20Bridge} from 'src/bridges/arbitrum/AaveArbEthERC20Bridge.sol';
import {AavePolEthERC20Bridge} from 'src/bridges/polygon/AavePolEthERC20Bridge.sol';
import {AavePolEthPlasmaBridge} from 'src/bridges/polygon/AavePolEthPlasmaBridge.sol';
import {AaveOpEthERC20Bridge} from 'src/bridges/optimism/AaveOpEthERC20Bridge.sol';
import {AaveCcipGhoBridge} from 'src/bridges/chainlink-ccip/AaveCcipGhoBridge.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

contract DeployEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Bridge';
    new AavePolEthERC20Bridge{salt: salt}(GovernanceV3Ethereum.EXECUTOR_LVL_1);
  }
}

contract DeployPolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Bridge';
    new AavePolEthERC20Bridge{salt: salt}(GovernanceV3Polygon.EXECUTOR_LVL_1);
  }
}

contract DeployPlasmaEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Plasma Bridge';
    new AavePolEthPlasmaBridge{salt: salt}(0x3765A685a401622C060E5D700D9ad89413363a91);
  }
}

contract DeployPlasmaPolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Plasma Bridge';
    new AavePolEthPlasmaBridge{salt: salt}(0x3765A685a401622C060E5D700D9ad89413363a91);
  }
}

contract DeployOptimism is OptimismScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Optimism Bridge';
    new AaveOpEthERC20Bridge{salt: salt}(0x3765A685a401622C060E5D700D9ad89413363a91);
  }
}

contract DeployArbBridgeEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Bridge';
    new AaveArbEthERC20Bridge{salt: salt}(0x3765A685a401622C060E5D700D9ad89413363a91);
  }
}

contract DeployArbBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Bridge';
    new AaveArbEthERC20Bridge{salt: salt}(0x3765A685a401622C060E5D700D9ad89413363a91);
  }
}

contract DeployAaveCcipGhoBridgeEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'GHO Chainlink CCIP Bridge';
    new AaveCcipGhoBridge{salt: salt}(
      // https://etherscan.io/address/0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D
      0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D, // ccip router address
      AaveV3EthereumAssets.LINK_UNDERLYING,
      AaveV3EthereumAssets.GHO_UNDERLYING,
      address(AaveV3Ethereum.COLLECTOR),
      0x94A8518B76A3c45F5387B521695024379d43d715, // owner address
      0x94A8518B76A3c45F5387B521695024379d43d715 // guardian address
    );
  }
}

contract DeployAaveCcipGhoBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'GHO Chainlink CCIP Bridge';
    new AaveCcipGhoBridge{salt: salt}(
      // https://arbiscan.io/address/0x141fa059441E0ca23ce184B6A78bafD2A517DdE8
      0x141fa059441E0ca23ce184B6A78bafD2A517DdE8, // ccip router address
      AaveV3ArbitrumAssets.LINK_UNDERLYING,
      AaveV3ArbitrumAssets.GHO_UNDERLYING,
      address(AaveV3Arbitrum.COLLECTOR),
      0x94A8518B76A3c45F5387B521695024379d43d715, // owner address
      0x94A8518B76A3c45F5387B521695024379d43d715 // guardian address
    );
  }
}
