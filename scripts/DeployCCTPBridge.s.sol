// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';
import {ArbitrumScript, BaseScript, EthereumScript, OptimismScript, PolygonScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';
import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';

address constant TOKEN_LOGIC = 0x3765A685a401622C060E5D700D9ad89413363a91;

contract DeployCCTPBridgeEthereum is EthereumScript, CctpConstants {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      ETHEREUM_TOKEN_MESSENGER,
      ETHEREUM_USDC,
      ETHEREUM_DOMAIN,
      TOKEN_LOGIC
    );
  }
}

contract DeployCCTPBridgeArbitrum is ArbitrumScript, CctpConstants {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      ARBITRUM_TOKEN_MESSENGER,
      ARBITRUM_USDC,
      ARBITRUM_DOMAIN,
      TOKEN_LOGIC
    );
  }
}

contract DeployCCTPBridgeOptimism is OptimismScript, CctpConstants {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      OPTIMISM_TOKEN_MESSENGER,
      OPTIMISM_USDC,
      OPTIMISM_DOMAIN,
      TOKEN_LOGIC
    );
  }
}

contract DeployCCTPBridgePolygon is PolygonScript, CctpConstants {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      POLYGON_TOKEN_MESSENGER,
      POLYGON_USDC,
      POLYGON_DOMAIN,
      TOKEN_LOGIC
    );
  }
}

contract DeployCCTPBridgeBase is BaseScript, CctpConstants {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      BASE_TOKEN_MESSENGER,
      BASE_USDC,
      BASE_DOMAIN,
      TOKEN_LOGIC
    );
  }
}
