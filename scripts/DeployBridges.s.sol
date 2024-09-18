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
      0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D, // ccip router address
      0x514910771AF9Ca656af840dff83E8264EcF986CA, // ccip link token address
      0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f, // gho address
      0x3765A685a401622C060E5D700D9ad89413363a91, // owner address
      0x3765A685a401622C060E5D700D9ad89413363a91 // guardian address
    );
  }
}

contract DeployAaveCcipGhoBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'GHO Chainlink CCIP Bridge';
    new AaveCcipGhoBridge{salt: salt}(
      0x141fa059441E0ca23ce184B6A78bafD2A517DdE8, // ccip router address
      0xf97f4df75117a78c1A5a0DBb814Af92458539FB4, // ccip link token address
      0x7dfF72693f6A4149b17e7C6314655f6A9F7c8B33, // gho address
      0x3765A685a401622C060E5D700D9ad89413363a91, // owner address
      0x3765A685a401622C060E5D700D9ad89413363a91 // guardian address
    );
  }
}
