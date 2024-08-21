// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdStorage, StdStorage} from 'forge-std/Test.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';

import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';

import {AaveWeethWithdrawer} from '../../src/asset-manager/AaveWeethWithdrawer.sol';

interface IERC721 {
  function transferFrom(address from, address to, uint256 tokenId) external;
  function balanceOf(address from) external returns(uint256);
}

contract AaveWeethWithdrawerTest is Test {
  using stdStorage for StdStorage;
  
  event StartedWithdrawal(uint256[] amounts, uint256 indexed index);

  event FinalizedWithdrawal(uint256 amount, uint256 indexed index);
  
  /// At current block withdrawer has a withdrawal NFT
  ///   this NFT represents an WITHDRAWAL_AMOUNT of EETH that
  ///   yields FINALIZED_WITHDRAWAL_AMOUNT of ETH when completed.
  /// Most importantly, this withdrawal is ready to be finalized.
  uint256 public constant EXISTING_WITHDRAW_REQUESTID = 36881;
  uint256 public constant WITHDRAWAL_AMOUNT = 9835809070838274;
  address public constant OWNER = GovernanceV3Ethereum.EXECUTOR_LVL_1;
  address public constant GUARDIAN = 0x2cc1ADE245020FC5AAE66Ad443e1F66e01c54Df1;
  address public constant COLLECTOR = address(AaveV3Ethereum.COLLECTOR);
  IERC20 public constant WETH = IERC20(AaveV3EthereumAssets.WETH_UNDERLYING);
  IERC20 public constant WEETH = IERC20(AaveV3EthereumAssets.weETH_UNDERLYING);
  IERC721 public WITHDRAWAL_NFT;

  AaveWeethWithdrawer public withdrawer;
  
  /// the collector only has aEthweETH 
  modifier withWeeth() {
    vm.prank(0xBdfa7b7893081B35Fb54027489e2Bc7A38275129);
    WEETH.transfer(COLLECTOR, WITHDRAWAL_AMOUNT);
    _;
  }

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20576941);
    withdrawer = AaveWeethWithdrawer(payable(0x4D29D2eE3B039c51690e830d8a4ade0d4d03DDbe));
    WITHDRAWAL_NFT = IERC721(address(withdrawer.WITHDRAW_REQUEST_NFT()));
  }
}

contract TransferOwnership is AaveWeethWithdrawerTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert('Ownable: caller is not the owner');
    withdrawer.transferOwnership(makeAddr('new-admin'));
  }

  function test_successful() public {
    address newAdmin = makeAddr('new-admin');
    vm.startPrank(OWNER);
    withdrawer.transferOwnership(newAdmin);
    vm.stopPrank();

    assertEq(newAdmin, withdrawer.owner());
  }
}

contract UpdateGuardian is AaveWeethWithdrawerTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    withdrawer.updateGuardian(makeAddr('new-admin'));
  }

  function test_successful() public {
    address newManager = makeAddr('new-admin');
    vm.startPrank(OWNER);
    withdrawer.updateGuardian(newManager);
    vm.stopPrank();

    assertEq(newManager, withdrawer.guardian());
  }
}

contract StartWithdrawal is AaveWeethWithdrawerTest {
  function test_revertsIf_invalidCaller() public withWeeth {
    vm.prank(OWNER);
    AaveV3Ethereum.COLLECTOR.transfer(
      address(WEETH), 
      address(withdrawer), 
      WITHDRAWAL_AMOUNT
    );
    vm.expectRevert('ONLY_BY_OWNER_OR_GUARDIAN');
    withdrawer.startWithdraw(WITHDRAWAL_AMOUNT);
  }

  function test_startWithdrawalOwner() public withWeeth {
    uint256 weEthBalanceBefore = WEETH.balanceOf(address(withdrawer));
    uint256 nftBalanceBefore = WITHDRAWAL_NFT.balanceOf(address(withdrawer));

    vm.startPrank(OWNER);
    AaveV3Ethereum.COLLECTOR.transfer(
      address(WEETH),
      address(withdrawer),
      WITHDRAWAL_AMOUNT
    );
    // vm.expectEmit(address(withdrawer));
    // emit StartedWithdrawal(WITHDRAWAL_AMOUNT, nextIndex);
    withdrawer.startWithdraw(WITHDRAWAL_AMOUNT);
    vm.stopPrank();

    uint256 weEthBalanceAfter = WEETH.balanceOf(address(withdrawer));
    uint256 nftBalanceAfter = WITHDRAWAL_NFT.balanceOf(address(withdrawer));

    assertEq(weEthBalanceAfter, weEthBalanceBefore);
    assertEq(nftBalanceAfter, nftBalanceBefore + 1);
  }

  function test_startWithdrawalGuardian() public withWeeth {
    uint256 weEthBalanceBefore = WEETH.balanceOf(address(withdrawer));
    uint256 nftBalanceBefore = WITHDRAWAL_NFT.balanceOf(address(withdrawer));

    vm.startPrank(OWNER);
    AaveV3Ethereum.COLLECTOR.transfer(
      address(WEETH),
      address(withdrawer),
      WITHDRAWAL_AMOUNT
    );
    // vm.expectEmit(address(withdrawer));
    // emit StartedWithdrawal(WITHDRAWAL_AMOUNT, nextIndex);
    withdrawer.startWithdraw(WITHDRAWAL_AMOUNT);
    vm.stopPrank();

    uint256 weEthBalanceAfter = WEETH.balanceOf(address(withdrawer));
    uint256 nftBalanceAfter = WITHDRAWAL_NFT.balanceOf(address(withdrawer));

    assertEq(weEthBalanceAfter, weEthBalanceBefore);
    assertEq(nftBalanceAfter, nftBalanceBefore + 1);
  }
}

contract FinalizeWithdrawal is AaveWeethWithdrawerTest {
  function test_finalizeWithdrawalGuardian() public {
    uint256 collectorBalanceBefore = WETH.balanceOf(COLLECTOR);
    vm.startPrank(GUARDIAN);
    vm.expectEmit(address(withdrawer));
    emit FinalizedWithdrawal(WITHDRAWAL_AMOUNT, EXISTING_WITHDRAW_REQUESTID);
    withdrawer.finalizeWithdraw(EXISTING_WITHDRAW_REQUESTID);
    vm.stopPrank();

    uint256 collectorBalanceAfter = WETH.balanceOf(COLLECTOR);

    assertEq(collectorBalanceAfter, collectorBalanceBefore + WITHDRAWAL_AMOUNT);
  }

  function test_finalizeWithdrawalOwner() public {
    uint256 collectorBalanceBefore = WETH.balanceOf(COLLECTOR);
    vm.startPrank(OWNER);
    vm.expectEmit(address(withdrawer));
    emit FinalizedWithdrawal(WITHDRAWAL_AMOUNT, EXISTING_WITHDRAW_REQUESTID);
    withdrawer.finalizeWithdraw(EXISTING_WITHDRAW_REQUESTID);
    vm.stopPrank();

    uint256 collectorBalanceAfter = WETH.balanceOf(COLLECTOR);

    assertEq(collectorBalanceAfter, collectorBalanceBefore + WITHDRAWAL_AMOUNT);
  }
  
  function test_finalizeWithdrawalWithExtraFunds() public {
    uint256 collectorBalanceBefore = WETH.balanceOf(COLLECTOR);

    /// send 1 wei to withdrawers
    vm.deal(address(withdrawer), 1);

    vm.startPrank(OWNER);
    vm.expectEmit(address(withdrawer));
    emit FinalizedWithdrawal(WITHDRAWAL_AMOUNT + 1, EXISTING_WITHDRAW_REQUESTID);
    withdrawer.finalizeWithdraw(EXISTING_WITHDRAW_REQUESTID);
    vm.stopPrank();

    uint256 collectorBalanceAfter = WETH.balanceOf(COLLECTOR);

    assertEq(collectorBalanceAfter, collectorBalanceBefore + WITHDRAWAL_AMOUNT + 1);
  }
}

contract EmergencyTokenTransfer is AaveWeethWithdrawerTest {
  function test_revertsIf_invalidCaller() public {
    deal(address(WEETH), address(withdrawer), WITHDRAWAL_AMOUNT);
    vm.expectRevert('ONLY_RESCUE_GUARDIAN');
    withdrawer.emergencyTokenTransfer(
      address(WEETH),
      COLLECTOR,
      WITHDRAWAL_AMOUNT
    );
  }

  function test_successful_governanceCaller() public {
    uint256 initialCollectorBalance = WEETH.balanceOf(COLLECTOR);
    deal(address(WEETH), address(withdrawer), WITHDRAWAL_AMOUNT);
    vm.startPrank(OWNER);
    withdrawer.emergencyTokenTransfer(
      address(WEETH),
      COLLECTOR,
      WITHDRAWAL_AMOUNT
    );
    vm.stopPrank();

    assertEq(
      WEETH.balanceOf(COLLECTOR),
      initialCollectorBalance + WITHDRAWAL_AMOUNT
    );
    assertEq(WEETH.balanceOf(address(withdrawer)), 0);
  }
}

contract Emergency721TokenTransfer is AaveWeethWithdrawerTest {
  function test_revertsIf_invalidCaller() public {
    vm.expectRevert('ONLY_RESCUE_GUARDIAN');
    withdrawer.emergency721TokenTransfer(
      address(WITHDRAWAL_NFT),
      COLLECTOR,
      EXISTING_WITHDRAW_REQUESTID
    );
  }

  function test_successful_governanceCaller() public {
    uint256 lidoNftBalanceBefore = WITHDRAWAL_NFT.balanceOf(address(withdrawer));
    vm.startPrank(OWNER);
    withdrawer.emergency721TokenTransfer(
      address(WITHDRAWAL_NFT),
      COLLECTOR,
      EXISTING_WITHDRAW_REQUESTID
    );
    vm.stopPrank();

    uint256 lidoNftBalanceAfter = WITHDRAWAL_NFT.balanceOf(address(withdrawer));

    assertEq(
      WITHDRAWAL_NFT.balanceOf(COLLECTOR),
      1
    );
    assertEq(lidoNftBalanceAfter, lidoNftBalanceBefore - 1);
  }
}