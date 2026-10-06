// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;
// Vendored from https://github.com/cowprotocol/composable-cow/blob/c0435953ac8312a606d66c91554f2bb4d22ec686/src/ERC1271Forwarder.sol
// composable-cow tag ack3-rev2.0 (file last changed in 9f0c6110ec2eb498341a0d45a0168e735a18ed1b).
// Local changes: import paths; Safe ERC1271 base replaced by OpenZeppelin IERC1271; ComposableCoW replaced by IComposableCow, so the owner is passed as address(this) instead of Safe(payable(address(this))).

import {IERC1271} from 'openzeppelin-contracts/contracts/interfaces/IERC1271.sol';
import {GPv2Order} from './GPv2Order.sol';

import {IComposableCow} from '../../interfaces/IComposableCow.sol';

/**
 * @title ERC1271 Forwarder - An abstract contract that implements ERC1271 forwarding to ComposableCoW
 * @author mfw78 <mfw78@rndlabs.xyz>
 * @dev Designed to be extended from by a contract that wants to use ComposableCoW
 */
abstract contract ERC1271Forwarder is IERC1271 {
  // forge-lint: disable-next-line(screaming-snake-case-immutable) -- integration surface; renaming breaks contracts that inherit this
  IComposableCow public immutable composableCoW;

  constructor(IComposableCow _composableCoW) {
    composableCoW = _composableCoW;
  }

  // When the pre-image doesn't match the hash, revert with this error.
  error InvalidHash();

  /**
   * Re-arrange the request into something that ComposableCoW can understand
   * @param _hash GPv2Order.Data digest
   * @param signature The abi.encoded tuple of (GPv2Order.Data, ComposableCoW.PayloadStruct)
   */
  function isValidSignature(
    bytes32 _hash,
    bytes memory signature
  ) public view override returns (bytes4) {
    (GPv2Order.Data memory order, IComposableCow.PayloadStruct memory payload) = abi.decode(
      signature,
      (GPv2Order.Data, IComposableCow.PayloadStruct)
    );
    bytes32 domainSeparator = composableCoW.domainSeparator();
    if (!(GPv2Order.hash(order, domainSeparator) == _hash)) {
      revert InvalidHash();
    }

    return
      composableCoW.isValidSafeSignature(
        address(this), // owner
        msg.sender, // sender
        _hash, // GPv2Order digest
        domainSeparator, // GPv2Settlement domain separator
        bytes32(0), // typeHash (not used by ComposableCoW)
        abi.encode(order), // GPv2Order
        abi.encode(payload) // ComposableCoW.PayloadStruct
      );
  }
}
