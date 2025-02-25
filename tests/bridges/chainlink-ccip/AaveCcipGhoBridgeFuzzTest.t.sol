// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {ERC20Mock} from 'openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol';
import {MockCCIPRouter, Client, IRouterClient} from './mocks/MockRouter.sol';

import {AaveCcipGhoBridge, IAaveCcipGhoBridge, CCIPReceiver} from 'src/bridges/chainlink-ccip/AaveCcipGhoBridge.sol';

/// @dev forge test --match-path=tests/bridges/chainlink-ccip/AaveCcipGhoBridgeFuzzTest.t.sol -vvv
contract AaveCcipGhoBridgeTest is Test {
  uint64 public constant sourceChainSelector = 5009297550715157269;
  uint64 public constant destinationChainSelector = 4949039107694359620;

  uint256 public constant mockFee = 0.01 ether;

  IRouterClient public ccipRouter;
  IERC20 public gho;
  address public collector;
  address public owner;
  address public alice;
  address public destinationBridge;

  AaveCcipGhoBridge bridge;

  function setUp() public {
    collector = makeAddr('collector');
    owner = makeAddr('owner');
    alice = makeAddr('alice');
    destinationBridge = makeAddr('destBridge');

    MockCCIPRouter mockRouter = new MockCCIPRouter();
    ccipRouter = IRouterClient(address(mockRouter));
    mockRouter.setFee(mockFee);

    ERC20Mock mockGho = new ERC20Mock();
    gho = IERC20(address(mockGho));

    bridge = new AaveCcipGhoBridge(address(mockRouter), address(mockGho), collector, owner);

    vm.startPrank(alice);
    gho.approve(address(bridge), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(owner);
    bridge.setDestinationBridge(destinationChainSelector, destinationBridge);
    bridge.grantRole(bridge.BRIDGER_ROLE(), alice);
    vm.stopPrank();
  }

  function testFuzz_BridgeWithGhoFee(uint256 amount, uint256 gasLimit) public {
    vm.assume(amount > 0 && amount < 1_000_000_000_000_000 ether);
    vm.assume(gasLimit < 10_000_000);

    deal(address(gho), alice, amount + mockFee);
    vm.startPrank(alice);

    Client.EVM2AnyMessage memory message = _buildCCIPMessage(amount, gasLimit, address(gho));

    // Mock CCIP router's fee estimate
    vm.mockCall(
      address(ccipRouter),
      abi.encodeWithSelector(ccipRouter.getFee.selector, destinationChainSelector, message),
      abi.encode(mockFee)
    );

    // Expect call to CCIP send function
    vm.expectCall(
      address(ccipRouter),
      abi.encodeWithSelector(ccipRouter.ccipSend.selector, destinationChainSelector, message)
    );
    bridge.bridge(destinationChainSelector, amount, gasLimit, address(gho));
    vm.stopPrank();
  }

  function testFuzz_BridgeWithEthFee(uint256 amount, uint256 gasLimit) public {
    vm.assume(amount > 0 && amount < 1_000_000_000_000_000 ether);
    vm.assume(gasLimit < 10_000_000);

    deal(address(gho), alice, amount);
    deal(alice, mockFee);
    vm.startPrank(alice);

    Client.EVM2AnyMessage memory message = _buildCCIPMessage(amount, gasLimit, address(0));

    // Mock CCIP router's fee estimate
    vm.mockCall(
      address(ccipRouter),
      abi.encodeWithSelector(ccipRouter.getFee.selector, destinationChainSelector, message),
      abi.encode(mockFee)
    );

    // Expect call to CCIP send function
    vm.expectCall(
      address(ccipRouter),
      abi.encodeWithSelector(ccipRouter.ccipSend.selector, destinationChainSelector, message)
    );
    bridge.bridge{value: mockFee}(destinationChainSelector, amount, gasLimit, address(0));
    vm.stopPrank();
  }

  function testFuzz_QuoteBridge(uint256 amount, uint256 gasLimit) public view {
    vm.assume(amount > 0);
    vm.assume(gasLimit < 10_000_000);

    uint256 fee = bridge.quoteBridge(destinationChainSelector, amount, gasLimit, address(0));
    assertEq(fee, mockFee);
  }

  function _buildCCIPMessage(
    uint256 amount,
    uint256 gasLimit,
    address feeToken
  ) internal view returns (Client.EVM2AnyMessage memory message) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: address(gho), amount: amount});

    message = Client.EVM2AnyMessage({
      receiver: abi.encode(destinationBridge),
      data: '',
      tokenAmounts: tokenAmounts,
      extraArgs: gasLimit == 0
        ? bytes('')
        : Client._argsToBytes(
          Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: false})
        ),
      feeToken: feeToken
    });
  }
}
