// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {GovernanceV3Plasma} from 'aave-address-book/GovernanceV3Plasma.sol';
import {ArbitrumScript, EthereumScript, OptimismScript, PolygonScript, PlasmaScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveOFTBridge} from 'src/bridges/OFT/AaveOFTBridge.sol';
import {TOKEN_LOGIC} from './DeployBridges.s.sol';

contract DeployOFTEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridge{salt: salt}(
      0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee, // USDT0 OFT (OAdapterUpgradeable)
      0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
      TOKEN_LOGIC // owner
    );
  }
}

contract DeployOFTArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridge{salt: salt}(
      0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92, // USDT0 OFT (OUpgradeable)
      0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT
      TOKEN_LOGIC // owner
    );
  }
}

contract DeployOFTPolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridge{salt: salt}(
      0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13, // USDT0 OFT (OUpgradeable)
      0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // USDT
      TOKEN_LOGIC // owner
    );
  }
}

contract DeployOFTOptimism is OptimismScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridge{salt: salt}(
      0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD, // USDT0 OFT (OUpgradeable)
      0x01bFF41798a0BcF287b996046Ca68b395DbC1071, // USDT0 Token
      TOKEN_LOGIC // owner
    );
  }
}

contract DeployOFTPlasma is PlasmaScript {
  function run() external broadcast {
    bytes32 salt = 'Aave Treasury OFT Bridge';
    new AaveOFTBridge{salt: salt}(
      0x02ca37966753bDdDf11216B73B16C1dE756A7CF9, // USDT0 OFT (OUpgradeable)
      0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb, // USDT0 Token
      TOKEN_LOGIC // owner
    );
  }
}
