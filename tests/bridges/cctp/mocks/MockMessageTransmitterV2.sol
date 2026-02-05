// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageTransmitterV2} from 'src/bridges/cctp/interfaces/IMessageTransmitterV2.sol';

contract MockMessageTransmitterV2 is IMessageTransmitterV2 {
  uint32 internal immutable _localDomain;

  constructor(uint32 localDomain_) {
    _localDomain = localDomain_;
  }

  function localDomain() external view returns (uint32) {
    return _localDomain;
  }
}
