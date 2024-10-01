// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {ArbitrumScript, EthereumScript, OptimismScript, PolygonScript} from 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveArbEthERC20Bridge} from 'src/bridges/arbitrum/AaveArbEthERC20Bridge.sol';
import {AavePolEthERC20Bridge} from 'src/bridges/polygon/AavePolEthERC20Bridge.sol';
import {AavePolEthPlasmaBridge} from 'src/bridges/polygon/AavePolEthPlasmaBridge.sol';
import {AaveOpEthERC20Bridge} from 'src/bridges/optimism/AaveOpEthERC20Bridge.sol';
import {AaveCctpBridge} from 'src/bridges/cctp/AaveCctpBridge.sol';

import {AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';

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

contract DeployAaveCctpBridgeEthereum is EthereumScript {
  function run() external broadcast {
    bytes32 salt = 'CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      // https://etherscan.io/address/0xBd3fa81B58Ba92a82136038B25aDec7066af3155
      0xBd3fa81B58Ba92a82136038B25aDec7066af3155, // token messenger of cctp
      // https://etherscan.io/address/0x0a992d191DEeC32aFe36203Ad87D7d289a738F81
      0x0a992d191DEeC32aFe36203Ad87D7d289a738F81, // message transmitter of cctp
      AaveV3EthereumAssets.USDC_UNDERLYING,
      GovernanceV3Ethereum.EXECUTOR_LVL_1, // owner address
      // https://app.safe.global/home?safe=eth:0x2CFe3ec4d5a6811f4B8067F0DE7e47DfA938Aa30
      0x2CFe3ec4d5a6811f4B8067F0DE7e47DfA938Aa30 // guardian address
    );
  }
}

contract DeployAaveCctpBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    bytes32 salt = 'CCTP Bridge';
    new AaveCctpBridge{salt: salt}(
      // https://arbiscan.io/address/0x19330d10D9Cc8751218eaf51E8885D058642E08A
      0x19330d10D9Cc8751218eaf51E8885D058642E08A, // token messenger of cctp
      // https://arbiscan.io/address/0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca
      0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca, // message transmitter of cctp
      AaveV3ArbitrumAssets.USDCn_UNDERLYING,
      GovernanceV3Arbitrum.EXECUTOR_LVL_1, // owner address
      // https://app.safe.global/home?safe=arb1:0xCb45E82419baeBCC9bA8b1e5c7858e48A3B26Ea6
      0xCb45E82419baeBCC9bA8b1e5c7858e48A3B26Ea6 // guardian address
    );
  }
}
