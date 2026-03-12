// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {GovernanceV3Plasma} from 'aave-address-book/GovernanceV3Plasma.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {ArbitrumScript, EthereumScript, OptimismScript, PolygonScript, PlasmaScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveOFTBridgeSteward} from 'src/bridges/oft/AaveOFTBridgeSteward.sol';
import {TOKEN_LOGIC} from './DeployBridges.s.sol';

contract DeployOFTEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridgeSteward{salt: salt}(
      0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee, // USDT0 OFT (OAdapterUpgradeable)
      TOKEN_LOGIC, // owner
      GovernanceV3Ethereum.EXECUTOR_LVL_1, // guardian
      address(AaveV3Ethereum.COLLECTOR) // collector
    );
  }
}

contract DeployOFTArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridgeSteward{salt: salt}(
      0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92, // USDT0 OFT (OUpgradeable)
      TOKEN_LOGIC, // owner
      GovernanceV3Arbitrum.EXECUTOR_LVL_1, // guardian
      address(AaveV3Arbitrum.COLLECTOR) // collector
    );
  }
}

contract DeployOFTPolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridgeSteward{salt: salt}(
      0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13, // USDT0 OFT (OUpgradeable)
      TOKEN_LOGIC, // owner
      GovernanceV3Polygon.EXECUTOR_LVL_1, // guardian
      address(AaveV3Polygon.COLLECTOR) // collector
    );
  }
}

contract DeployOFTOptimism is OptimismScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridgeSteward{salt: salt}(
      0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD, // USDT0 OFT (OUpgradeable)
      TOKEN_LOGIC, // owner
      GovernanceV3Optimism.EXECUTOR_LVL_1, // guardian
      address(AaveV3Optimism.COLLECTOR) // collector
    );
  }
}

contract DeployOFTPlasma is PlasmaScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridgeSteward{salt: salt}(
      0x02ca37966753bDdDf11216B73B16C1dE756A7CF9, // USDT0 OFT (OUpgradeable)
      TOKEN_LOGIC, // owner
      GovernanceV3Plasma.EXECUTOR_LVL_1, // guardian
      address(AaveV3Plasma.COLLECTOR) // collector
    );
  }
}
