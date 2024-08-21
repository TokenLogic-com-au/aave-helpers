// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {AaveWeethWithdrawer} from 'src/asset-manager/AaveWeethWithdrawer.sol';

contract DeployAaveWeethWithdrawer is Script {
  function run() external {
    vm.startBroadcast();

    address aaveWithdrawer = address(new AaveWeethWithdrawer());
    TransparentProxyFactory(MiscEthereum.TRANSPARENT_PROXY_FACTORY).create(
      aaveWithdrawer,
      MiscEthereum.PROXY_ADMIN,
      abi.encodeWithSelector(AaveWeethWithdrawer.initialize.selector)
    );
    
    vm.stopBroadcast();
  }
}
