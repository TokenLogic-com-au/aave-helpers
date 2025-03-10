// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';

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
  address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public bridgedUSDT = 0x6047828dc181963ba44974801FF68e538dA5eaF9;

  function setUp() public {
    owner = makeAddr('owner');
    guardian = makeAddr('guardian');

    bytes32 salt = keccak256(abi.encode(tx.origin, uint256(0)));
    mainnetFork = vm.createSelectFork(vm.rpcUrl('mainnet'));
    bridgeMainnet = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);

    sonicFork = vm.createSelectFork(vm.rpcUrl('sonic'));
    bridgeSonic = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);

    vm.selectFork(mainnetFork);
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
    vm.selectFork(sonicFork);
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

  function test_revertsIf_InvalidParam_batch() public {
    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);

    deal(USDC, address(bridgeMainnet), amount);
    deal(USDT, address(bridgeMainnet), amount);

    address[] memory tokens = new address[](2);
    tokens[0] = USDC;
    tokens[1] = USDT;

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amount;

    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidParam.selector);
    bridgeMainnet.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function test_success_batch() public {
    vm.startPrank(guardian);
    vm.selectFork(mainnetFork);

    deal(USDC, address(bridgeMainnet), amount);
    deal(USDT, address(bridgeMainnet), amount);

    address[] memory tokens = new address[](2);
    tokens[0] = USDC;
    tokens[1] = USDT;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount;
    amounts[1] = amount;

    vm.expectEmit(true, true, false, true);
    emit Bridge(USDC, amount);
    emit Bridge(USDT, amount);
    bridgeMainnet.deposit(tokens, amounts);
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

  function test_revertsIf_InvalidParam_batch() public {
    vm.startPrank(guardian);
    vm.selectFork(sonicFork);

    deal(bridgedUSDC, address(bridgeSonic), amount);
    deal(bridgedUSDT, address(bridgeSonic), amount);

    address[] memory tokens = new address[](2);
    tokens[0] = USDC;
    tokens[1] = USDT;

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amount;

    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidParam.selector);
    bridgeSonic.withdraw(tokens, amounts);
    vm.stopPrank();
  }

  function test_success_batch() public {
    vm.startPrank(guardian);
    vm.selectFork(sonicFork);

    deal(bridgedUSDC, address(bridgeSonic), amount);
    deal(bridgedUSDT, address(bridgeSonic), amount);

    address[] memory tokens = new address[](2);
    tokens[0] = USDC;
    tokens[1] = USDT;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount;
    amounts[1] = amount;

    vm.expectEmit(true, true, false, true);
    emit Bridge(USDC, amount);
    emit Bridge(USDT, amount);
    bridgeSonic.withdraw(tokens, amounts);
    vm.stopPrank();
  }
}

contract TransferOwnership is AaveSonicEthERC20BridgeTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    bridgeMainnet.transferOwnership(makeAddr('new-admin'));
  }

  function test_successful() public {
    address newAdmin = makeAddr('new-admin');
    vm.startPrank(owner);
    bridgeMainnet.transferOwnership(newAdmin);
    vm.stopPrank();

    assertEq(newAdmin, bridgeMainnet.owner());
  }
}

contract UpdateGuardian is AaveSonicEthERC20BridgeTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(this))
    );
    bridgeMainnet.updateGuardian(makeAddr('new-admin'));
  }

  function test_successful() public {
    address newManager = makeAddr('new-admin');
    vm.startPrank(owner);
    bridgeMainnet.updateGuardian(newManager);
    vm.stopPrank();

    assertEq(newManager, bridgeMainnet.guardian());
  }
}

contract EmergencyTokenTransfer is AaveSonicEthERC20BridgeTest {
  uint256 amount = 1_000e18;

  function test_successful() public {
    uint256 initialCollectorBalance = IERC20(USDC).balanceOf(address(AaveV3Ethereum.COLLECTOR));
    deal(USDC, address(bridgeMainnet), amount);
    vm.startPrank(owner);
    bridgeMainnet.emergencyTokenTransfer(USDC, amount);
    vm.stopPrank();

    assertEq(
      IERC20(USDC).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      initialCollectorBalance + amount
    );
    assertEq(IERC20(USDC).balanceOf(address(bridgeMainnet)), 0);
  }
}
