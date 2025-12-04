// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {GovernanceV3Plasma} from 'aave-address-book/GovernanceV3Plasma.sol';
import {ArbitrumScript, EthereumScript, OptimismScript, PolygonScript, PlasmaScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveArbEthERC20Bridge} from 'src/bridges/arbitrum/AaveArbEthERC20Bridge.sol';
import {AavePolEthERC20Bridge} from 'src/bridges/polygon/AavePolEthERC20Bridge.sol';
import {AavePolEthPlasmaBridge} from 'src/bridges/polygon/AavePolEthPlasmaBridge.sol';
import {AaveOpEthERC20Bridge} from 'src/bridges/optimism/AaveOpEthERC20Bridge.sol';
import {AaveStargateBridge} from 'src/bridges/stargate/AaveStargateBridge.sol';

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

contract DeployStargateEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Stargate Bridge';
    new AaveStargateBridge{salt: salt}(
      0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee, // USDT0 OFT (OAdapterUpgradeable)
      0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
      0x3765A685a401622C060E5D700D9ad89413363a91  // owner
    );
  }
}

contract DeployStargateArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Stargate Bridge';
    new AaveStargateBridge{salt: salt}(
      0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92, // USDT0 OFT (OUpgradeable)
      0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT
      0x3765A685a401622C060E5D700D9ad89413363a91 // owner
    );
  }
}

contract DeployStargatePolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Stargate Bridge';
    new AaveStargateBridge{salt: salt}(
      0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13, // USDT0 OFT (OUpgradeable)
      0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // USDT
      0x3765A685a401622C060E5D700D9ad89413363a91 // owner
    );
  }
}

contract DeployStargateOptimism is OptimismScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Stargate Bridge';
    new AaveStargateBridge{salt: salt}(
      0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD, // USDT0 OFT (OUpgradeable)
      0x01bFF41798a0BcF287b996046Ca68b395DbC1071, // USDT0 Token
      0x3765A685a401622C060E5D700D9ad89413363a91  // owner
    );
  }
}

contract DeployStargatePlasma is PlasmaScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury Stargate Bridge';
    new AaveStargateBridge{salt: salt}(
      0x02ca37966753bDdDf11216B73B16C1dE756A7CF9, // USDT0 OFT (OUpgradeable)
      0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb, // USDT0 Token
      0x3765A685a401622C060E5D700D9ad89413363a91  // owner
    );
  }
}
