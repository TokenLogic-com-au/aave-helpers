// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Rescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {IAaveStargateBridge} from "./IAaveStargateBridge.sol";
import {IOFT, SendParam, MessagingFee, OFTReceipt} from "./IOFT.sol";

/// @title AaveStargateBridge
/// @author Aave
/// @notice Helper contract to bridge USDT using Stargate V2 (LayerZero OFT)
contract AaveStargateBridge is Ownable, Rescuable, IAaveStargateBridge {
    using SafeERC20 for IERC20;

    /// @inheritdoc IAaveStargateBridge
    address public immutable OFT_USDT;

    /// @inheritdoc IAaveStargateBridge
    address public immutable USDT;

    /// @param oftUsdt The OFT address for USDT on this chain
    /// @param usdt The USDT token address on this chain
    /// @param owner The owner of the contract upon deployment
    constructor(address oftUsdt, address usdt, address owner) Ownable(owner) {
        OFT_USDT = oftUsdt;
        USDT = usdt;
    }

    /// @dev Default receive function enabling the contract to accept native tokens for refunds
    receive() external payable {}

    /// @inheritdoc IAaveStargateBridge
    function bridge(uint32 dstEid, uint256 amount, address receiver, uint256 minAmountLD) external payable onlyOwner {
        if (amount == 0) revert InvalidZeroAmount();

        SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, minAmountLD);

        MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);

        IERC20(USDT).forceApprove(OFT_USDT, amount);

        IOFT(OFT_USDT).send{value: messagingFee.nativeFee}(sendParam, messagingFee, msg.sender);

        emit Bridge(USDT, dstEid, receiver, amount, minAmountLD);
    }

    /// @inheritdoc IAaveStargateBridge
    function quoteBridge(uint32 dstEid, uint256 amount, address receiver, uint256 minAmountLD)
        external
        view
        returns (uint256 nativeFee)
    {
        SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, minAmountLD);
        MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);
        return messagingFee.nativeFee;
    }

    /// @inheritdoc IAaveStargateBridge
    function quoteOFT(uint32 dstEid, uint256 amount, address receiver)
        external
        view
        returns (uint256 amountReceivedLD)
    {
        SendParam memory sendParam = _buildSendParam(dstEid, amount, receiver, 0);
        (,, OFTReceipt memory receipt) = IOFT(OFT_USDT).quoteOFT(sendParam);
        return receipt.amountReceivedLD;
    }

    /// @inheritdoc Rescuable
    function whoCanRescue() public view override returns (address) {
        return owner();
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(address) public pure override(RescuableBase, IRescuableBase) returns (uint256) {
        return type(uint256).max;
    }

    /// @dev Builds the SendParam struct for Stargate transfer
    /// @param dstEid The destination LayerZero endpoint ID
    /// @param amount The amount to send
    /// @param receiver The receiver address on destination
    /// @param minAmountLD The minimum amount to receive
    /// @return sendParam The constructed SendParam struct
    function _buildSendParam(uint32 dstEid, uint256 amount, address receiver, uint256 minAmountLD)
        internal
        pure
        returns (SendParam memory sendParam)
    {
        sendParam = SendParam({
            dstEid: dstEid,
            to: _addressToBytes32(receiver),
            amountLD: amount,
            minAmountLD: minAmountLD,
            extraOptions: new bytes(0),
            composeMsg: new bytes(0),
            oftCmd: new bytes(0) // Empty bytes for taxi mode (immediate)
        });
    }

    /// @dev Converts an address to bytes32
    /// @param addr The address to convert
    /// @return The bytes32 representation
    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
