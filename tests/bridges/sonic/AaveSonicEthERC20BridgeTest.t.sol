// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';

import {AaveSonicEthERC20Bridge, IAaveSonicEthERC20Bridge} from 'src/bridges/sonic/AaveSonicEthERC20Bridge.sol';

/// forge test --match-path tests/bridges/sonic/AaveSonicEthERC20BridgeTest.t.sol -vvv
contract AaveSonicEthERC20BridgeTest is Test {
  event Bridge(address indexed token, uint256 amount);
  event Claim(address indexed token, uint256 amount);
  event WithdrawToCollector(address indexed token, uint256 amount);

  AaveSonicEthERC20Bridge bridgeMainnet;
  AaveSonicEthERC20Bridge bridgeSonic;
  uint256 mainnetFork;
  uint256 sonicFork;

  address public owner;
  address public guardian;

  address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public bridgedUSDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;

  function setUp() public {
    owner = makeAddr('owner');
    guardian = makeAddr('guardian');

    bytes32 salt = keccak256(abi.encode(tx.origin, uint256(0)));
    mainnetFork = vm.createSelectFork(vm.rpcUrl('mainnet'));
    bridgeMainnet = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);

    sonicFork = vm.createSelectFork(vm.rpcUrl('sonic'));
    bridgeSonic = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);
  }
}

contract DepositTest is AaveSonicEthERC20BridgeTest {
  uint256 amount = 1_000e6;

  function test_revertsIf_notOwnerOrGuardian() public {
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(this))
    );
    bridgeMainnet.deposit(USDC, amount);
  }

  function test_revertsIf_InvalidChainId() public {
    vm.startPrank(guardian);
    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidChain.selector);
    bridgeMainnet.deposit(USDC, amount);
    vm.stopPrank();
  }

  function test_revertsIf_InsufficientToken() public {
    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);
    vm.expectRevert();
    bridgeMainnet.deposit(USDC, amount);
    vm.stopPrank();
  }

  function test_revertsIf_InvalidToken() public {
    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);
    vm.expectRevert();
    bridgeMainnet.deposit(bridgedUSDC, amount);
    vm.stopPrank();
  }

  function testFuzz_success(uint256 testAmount) public {
    vm.assume(testAmount > 0 && testAmount < 1e32); // set max to prevent overflow errors

    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);
    deal(USDC, address(bridgeMainnet), testAmount);

    vm.expectEmit(true, true, false, true);
    emit Bridge(USDC, testAmount);
    bridgeMainnet.deposit(USDC, testAmount);
    vm.stopPrank();
  }
}

contract WithdrawTest is AaveSonicEthERC20BridgeTest {
  uint256 amount = 1_000e6;

  function test_revertsIf_notOwnerOrGuardian() public {
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(this))
    );
    bridgeMainnet.withdraw(USDC, amount);
  }

  function test_revertsIf_InvalidChainId() public {
    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);
    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidChain.selector);
    bridgeMainnet.withdraw(USDC, amount);
    vm.stopPrank();
  }

  function test_revertsIf_InsufficientToken() public {
    vm.startPrank(guardian);
    vm.selectFork(sonicFork);
    vm.expectRevert();
    bridgeMainnet.withdraw(USDC, amount);
    vm.stopPrank();
  }

  function test_revertsIf_InvalidToken() public {
    vm.startPrank(guardian);
    vm.selectFork(sonicFork);
    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidToken.selector);
    bridgeMainnet.withdraw(bridgedUSDC, amount);
    vm.stopPrank();
  }

  function testFuzz_success(uint256 testAmount) public {
    vm.assume(testAmount > 0 && testAmount < 1e32); // set max to prevent overflow errors

    vm.startPrank(guardian);
    vm.selectFork(sonicFork);
    deal(bridgedUSDC, address(bridgeMainnet), amount);

    vm.expectEmit(true, true, false, true);
    emit Bridge(USDC, amount);
    bridgeMainnet.withdraw(USDC, amount);
    vm.stopPrank();
  }
}
