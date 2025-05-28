// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {AccessControl, IAccessControl} from 'aave-v3-origin/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {IAaveGhoCcipBridge} from './IAaveGhoCcipBridge.sol';

contract AaveCcipGhoBridge is IAaveGhoCcipBridge {
    /// @dev This role defines which users can call bridge functions.
  bytes32 public constant BRIDGER_ROLE = keccak256('BRIDGER_ROLE');
}
