// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    AccessControl,
    IAccessControl
} from "aave-v3-origin/contracts/dependencies/openzeppelin/contracts/AccessControl.sol";
import {Rescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {Client} from "./libraries/Client.sol";
import {CCIPReceiver} from "./CCIPReceiver.sol";
import {IAaveGhoCcipBridge} from "./interfaces/IAaveGhoCcipBridge.sol";

contract AaveCcipGhoBridge is CCIPReceiver, AccessControl, Rescuable, IAaveGhoCcipBridge {
    using SafeERC20 for IERC20;

    /// @dev This role defines which users can call bridge functions.
    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");

    /// @inheritdoc IAaveGhoCcipBridge
    bytes32 public constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR_ROLE");

    /// @inheritdoc IAaveGhoCcipBridge
    address public immutable GHO_TOKEN;

    /// @inheritdoc IAaveGhoCcipBridge
    address public immutable ROUTER;

    /// @inheritdoc IAaveGhoCcipBridge
    address public immutable COLLECTOR;

    /// @inheritdoc IAaveGhoCcipBridge
    address public immutable EXECUTOR;

    /// @inheritdoc IAaveGhoCcipBridge
    mapping(uint64 selector => address bridge) public destinations;

    /**
     * @param router The address of the Chainlink CCIP router
     * @param gho The address of the GHO token
     * @param collector The address of collector on same chain
     * @param executor The address of the contract executor
     */
    constructor(address router, address gho, address collector, address executor) CCIPReceiver(router) {
        ROUTER = router;
        GHO = gho;
        COLLECTOR = collector;
        EXECUTOR = executor;

        _grantRole(DEFAULT_ADMIN_ROLE, executor);
    }

    /// @inheritdoc IAaveGhoCcipBridge
    function send(uint64 chainSelector, uint256 amount, uint256 gasLimit, address feeToken)
        external
        payable
        onlyRole(BRIDGER_ROLE)
        returns (bytes32)
    {
        _validateDestinationAndLimit(chainSelector, amount);
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(destinationChainSelector, amount, gasLimit, feeToken);

        uint256 fee = IRouterClient(ROUTER).getFee(destinationChainSelector, message);

        if (feeToken == address(0)) {
            if (msg.value < fee) revert InsufficientFee();
        } else {
            IERC20(feeToken).transferFrom(msg.sender, address(this), fee);
            IERC20(feeToken).approve(ROUTER, fee);
        }

        IERC20(GHO).transferFrom(msg.sender, address(this), amount);
        IERC20(GHO).approve(ROUTER, amount);

        bytes32 messageId =
            IRouterClient(ROUTER).ccipSend{value: feeToken == address(0) ? fee : 0}(chainSelector, message);

        emit BridgeInitiated(messageId, destinationChainSelector, msg.sender, amount);
    }

    /// @inheritdoc CCIPReceiver
    function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter {
        try this.processMessage(message) {}
        catch {
            bytes32 messageId = message.messageId;
            Client.EVMTokenAmount[] memory tokenAmounts = message.destTokenAmounts;

            uint256 length = tokenAmounts.length;
            for (uint256 i = 0; i < length; ++i) {
                invalidTokenTransfers[messageId].push(tokenAmounts[i]);
            }

            isInvalidMessage[messageId] = true;

            emit InvalidMessageReceived(messageId);
        }
    }

    /// @inheritdoc IAaveGhoCcipBridge
    function recoverFailedMessageTokens(bytes32 messageId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _validateMessageExists(messageId);
        isInvalidMessage[messageId] = false;

        Client.EVMTokenAmount[] memory tokenAmounts = invalidTokenTransfers[messageId];

        uint256 length = tokenAmounts.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC20(tokenAmounts[i].token).safeTransfer(COLLECTOR, tokenAmounts[i].amount);
        }

        emit HandledInvalidMessage(messageId);
    }

    /// @dev wraps _ccipReceive as a external function
    function processMessage(Client.Any2EVMMessage calldata message) external onlySelf {
        if (destinations[message.sourceChainSelector] != abi.decode(message.sender, (address))) {
            revert UnknownSourceDestination();
        }

        _ccipReceive(message);
    }

    /// @inheritdoc IAaveGhoCcipBridge
    function setDestinationBridge(uint64 chainSelector, address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bridge == address(0)) {
            revert InvalidZeroAddress();
        }

        destinations[chainSelector] = bridge;

        emit DestinationBridgeSet(chainSelector, bridge);
    }

    /// @inheritdoc IAaveGhoCcipBridge
    function getInvalidMessage(bytes32 messageId) external view returns (Client.EVMTokenAmount[] memory) {
        _validateMessageExists(messageId);

        uint256 length = invalidTokenTransfers[messageId].length;
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenAmounts[i] = invalidTokenTransfers[messageId][i];
        }

        return tokenAmounts;
    }

    /// @inheritdoc IAaveGhoCcipBridge
    function quoteBridge(uint64 chainSelector, uint256 amount, uint256 gasLimit, address feeToken)
        external
        view
        returns (uint256)
    {
        _validateDestinationAndLimit(chainSelector, amount);

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(chainSelector, amount, gasLimit, feeToken);

        return IRouterClient(ROUTER).getFee(chainSelector, message);
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(address token) public view override(RescuableBase, IRescuableBase) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc Rescuable
    function whoCanRescue() public view override returns (address) {
        return EXECUTOR;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(AccessControl, CCIPReceiver)
        returns (bool)
    {
        return interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev Builds ccip message for token transfer
     * @param chainSelector The selector of the destination chain
     * @param amount The amount of GHO to transfer
     * @param gasLimit The gas limit on the destination chain
     * @param feeToken The address of the fee token
     * @return message EVM2EVMMessage to transfer token
     */
    function _buildCCIPMessage(uint64 chainSelector, uint256 amount, uint256 gasLimit, address feeToken)
        internal
        view
        returns (Client.EVM2AnyMessage memory)
    {
        if (amount == 0) {
            revert InvalidZeroAmount();
        }
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: GHO, amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinations[chainSelector]),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: gasLimit == 0
                ? bytes("")
                : Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: false})),
            feeToken: feeToken
        });

        return message;
    }

    /// @inheritdoc CCIPReceiver
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        uint256 ghoAmount = message.destTokenAmounts[0].amount;

        IERC20(GHO).transfer(COLLECTOR, ghoAmount);

        emit BridgeFinalized(message.messageId, COLLECTOR, ghoAmount);
    }

    function _getRateLimit(uint64 chainSelector) internal view returns (uint128) {
        address onRamp = IRouter(ROUTER).getOnRamp(chainSelector);
        ITokenPool tokenPool = ITokenPool(IOnRampClient(onRamp).getPoolBySourceToken(chainSelector, GHO));
        (limit,,,,) = tokenPool.getCurrentOutboundRateLimiterState(chainSelector);

        return limit;
    }

    /// @dev Checks if the destination bridge has been set up and amount is exceed rate limit
    function _validateDestinationAndLimit(uint64 chainSelector, uint256 amount) internal {
        if (destinations[chainSelector] == address(0)) {
            revert UnsupportedChain();
        }

        uint128 limit = _getRateLimit(chainSelector);
        if (amount > limit) {
            revert RateLimitExceeded(limit);
        }
        _;
    }

    /// @dev Checks if invalid message exists
    function _validateMessageExists(bytes32 messageId) internal {
        if (!isInvalidMessage[messageId]) {
            revert MessageNotFound();
        }
    }
}
