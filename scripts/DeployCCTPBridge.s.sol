// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {ArbitrumScript, BaseScript, EthereumScript, OptimismScript, PolygonScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';
import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';

address constant TOKEN_LOGIC = 0x3765A685a401622C060E5D700D9ad89413363a91;
address constant GUARDIAN = 0x3765A685a401622C060E5D700D9ad89413363a91;

contract DeployCCTPBridgeEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Ethereum.COLLECTOR)
    );
  }
}

contract DeployCCTPBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      CctpConstants.ARBITRUM_TOKEN_MESSENGER,
      CctpConstants.ARBITRUM_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Arbitrum.COLLECTOR)
    );
  }
}

contract DeployCCTPBridgeOptimism is OptimismScript {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      CctpConstants.OPTIMISM_TOKEN_MESSENGER,
      CctpConstants.OPTIMISM_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Optimism.COLLECTOR)
    );
  }
}

contract DeployCCTPBridgePolygon is PolygonScript {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      CctpConstants.POLYGON_TOKEN_MESSENGER,
      CctpConstants.POLYGON_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Polygon.COLLECTOR)
    );
  }
}

contract DeployCCTPBridgeBase is BaseScript {
  function run() external broadcast {
    bytes32 salt = 'Aave CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      CctpConstants.BASE_TOKEN_MESSENGER,
      CctpConstants.BASE_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Base.COLLECTOR)
    );
  }
}
