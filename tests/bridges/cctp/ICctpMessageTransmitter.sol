// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICctpMessageTransmitter {
  // Events
  event AttesterDisabled(address indexed attester);
  event AttesterEnabled(address indexed attester);
  event AttesterManagerUpdated(
    address indexed previousAttesterManager,
    address indexed newAttesterManager
  );
  event MaxMessageBodySizeUpdated(uint256 newMaxMessageBodySize);
  event MessageReceived(
    address indexed caller,
    uint32 sourceDomain,
    uint64 indexed nonce,
    bytes32 sender,
    bytes messageBody
  );
  event MessageSent(bytes message);
  event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event Pause();
  event PauserChanged(address indexed newAddress);
  event RescuerChanged(address indexed newRescuer);
  event SignatureThresholdUpdated(uint256 oldSignatureThreshold, uint256 newSignatureThreshold);
  event Unpause();

  // Functions
  function acceptOwnership() external;

  function attesterManager() external view returns (address);

  function disableAttester(address attester) external;

  function enableAttester(address newAttester) external;

  function getEnabledAttester(uint256 index) external view returns (address);

  function getNumEnabledAttesters() external view returns (uint256);

  function isEnabledAttester(address attester) external view returns (bool);

  function localDomain() external view returns (uint32);

  function maxMessageBodySize() external view returns (uint256);

  function nextAvailableNonce() external view returns (uint64);

  function owner() external view returns (address);

  function pause() external;

  function paused() external view returns (bool);

  function pauser() external view returns (address);

  function pendingOwner() external view returns (address);

  function receiveMessage(
    bytes calldata message,
    bytes calldata attestation
  ) external returns (bool success);

  function replaceMessage(
    bytes calldata originalMessage,
    bytes calldata originalAttestation,
    bytes calldata newMessageBody,
    bytes32 newDestinationCaller
  ) external;

  function rescueERC20(address tokenContract, address to, uint256 amount) external;

  function rescuer() external view returns (address);

  function sendMessage(
    uint32 destinationDomain,
    bytes32 recipient,
    bytes calldata messageBody
  ) external returns (uint64);

  function sendMessageWithCaller(
    uint32 destinationDomain,
    bytes32 recipient,
    bytes32 destinationCaller,
    bytes calldata messageBody
  ) external returns (uint64);

  function setMaxMessageBodySize(uint256 newMaxMessageBodySize) external;

  function setSignatureThreshold(uint256 newSignatureThreshold) external;

  function signatureThreshold() external view returns (uint256);

  function transferOwnership(address newOwner) external;

  function unpause() external;

  function updateAttesterManager(address newAttesterManager) external;

  function updatePauser(address _newPauser) external;

  function updateRescuer(address newRescuer) external;

  function usedNonces(bytes32) external view returns (uint256);

  function version() external view returns (uint32);
}
