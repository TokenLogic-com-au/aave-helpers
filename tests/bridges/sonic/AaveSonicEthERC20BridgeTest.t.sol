// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IRescuable} from 'solidity-utils/contracts/utils/interfaces/IRescuable.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Sonic} from 'aave-address-book/AaveV3Sonic.sol';

import {AaveSonicEthERC20Bridge, IAaveSonicEthERC20Bridge} from 'src/bridges/sonic/AaveSonicEthERC20Bridge.sol';

/// forge test --match-path tests/bridges/sonic/AaveSonicEthERC20BridgeTestBase.t.sol -vvv
contract AaveSonicEthERC20BridgeTestBase is Test {
  AaveSonicEthERC20Bridge bridgeMainnet;
  AaveSonicEthERC20Bridge bridgeSonic;
  uint256 mainnetFork;
  uint256 sonicFork;
  uint256 invalidChainFork;

  // address of test deployer
  address public owner = 0x94A8518B76A3c45F5387B521695024379d43d715;
  address public guardian = 0x94A8518B76A3c45F5387B521695024379d43d715;

  address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public bridgedUSDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
  address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public bridgedUSDT = 0x6047828dc181963ba44974801FF68e538dA5eaF9;

  function setUp() public virtual {
    bytes32 salt = keccak256(abi.encode(tx.origin, uint256(0)));
    mainnetFork = vm.createFork(vm.rpcUrl('mainnet'), 22081205);
    sonicFork = vm.createFork(vm.rpcUrl('sonic'), 14633881);
    invalidChainFork = vm.createFork(vm.rpcUrl('arbitrum'), 318006219);

    vm.selectFork(mainnetFork);
    bridgeMainnet = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);

    vm.selectFork(sonicFork);
    bridgeSonic = new AaveSonicEthERC20Bridge{salt: salt}(owner, guardian);
  }
}

contract DepositTest is AaveSonicEthERC20BridgeTestBase {
  uint256 amount = 1_000e6;

  function test_revertsIf_notOwnerOrGuardian() public {
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(this))
    );
    bridgeMainnet.deposit(USDC, amount);
  }

  function test_revertsIf_InvalidChain() public {
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
    emit IAaveSonicEthERC20Bridge.Bridge(USDC, testAmount);
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

    vm.expectEmit(true, false, false, true, address(bridgeMainnet));
    emit IAaveSonicEthERC20Bridge.Bridge(USDC, amount);
    emit IAaveSonicEthERC20Bridge.Bridge(USDT, amount);
    bridgeMainnet.deposit(tokens, amounts);
    vm.stopPrank();
  }
}

contract WithdrawTest is AaveSonicEthERC20BridgeTestBase {
  uint256 amount = 1_000e6;

  function test_revertsIf_notOwnerOrGuardian() public {
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(this))
    );
    bridgeMainnet.withdraw(USDC, amount);
  }

  function test_revertsIf_InvalidChain() public {
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
    emit IAaveSonicEthERC20Bridge.Bridge(USDC, amount);
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

    vm.expectEmit(true, false, false, true, address(bridgeSonic));
    emit IAaveSonicEthERC20Bridge.Bridge(USDC, amount);
    emit IAaveSonicEthERC20Bridge.Bridge(USDT, amount);
    bridgeSonic.withdraw(tokens, amounts);
    vm.stopPrank();
  }
}

contract ClaimTestOnSonic is AaveSonicEthERC20BridgeTestBase {
  uint256 depositId = 83107629666763039256896161050088999267967285591997717212311752767753132459771;
  address token = USDC;
  uint256 amount = 10_000_000;

  function setUp() public override {
    super.setUp();
    vm.selectFork(sonicFork);
    // https://etherscan.io/address/0xb7bd405f4a43e9da2d5fbf3066c0c28e46f9306e
    bridgeSonic = AaveSonicEthERC20Bridge(payable(0xB7BD405f4a43E9DA2d5FbF3066C0C28E46F9306e));
  }

  function test_revertsIf_InvalidChain() public {
    vm.selectFork(invalidChainFork);
    IAaveSonicEthERC20Bridge invalidBridge = new AaveSonicEthERC20Bridge(owner, guardian);

    bytes memory proof = hex'f91722b90f03f900';

    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidChain.selector);
    invalidBridge.claim(depositId, token, amount, proof);
  }

  function test_revertsIf_AlreadyClaimed() public {
    bytes memory proof = hex'f91722b90f03f900';

    vm.expectRevert('Already claimed');
    bridgeSonic.claim(depositId, token, amount, proof);
  }

  function test_success() public {
    bytes32 storageSlot = keccak256(abi.encode(depositId, uint256(2)));
    vm.store(bridgeSonic.SONIC_BRIDGE(), storageSlot, bytes32(uint256(0)));

    bytes
      memory proof = hex'f91722b90f03f90f00b90214f90211a09bf4a14147bf8e6a09fb1fa810e0f7209eca1a90da67fe089fe7ec7795a9acd7a00d78a5eb1248d995d5bd8b397d4f1b0c6d4631828349a92e32d1add294aca723a0438a4a39c2422a3e3d2226dd8a9e6ed0dbc1e1e0ec1771c24a608f12165643eca0ac7fe9b66ead4f628fe2fa72863f7a77fac96260f91d634812f477258e8c7adea054139ffbbce1c31b99338cf6ff4cfb840c4672d7ad993a67739b9819def0d4b6a01cf2e9b78f1f08e6c6da78923711036e5812cbc6cef3bfab8e6c0af3b6333e7ca08a58e1159f78f7f0fa00379c743dda416cc0e87537348c15c713de77e4b10663a0f89f782e3ce146cdadd2e7cfef37117bc5624623388c590db9d16625248b1cafa0b5f83cb393fa3ba51a5cc2c764d00b16bec434e5b5710d2b52e04cd2222149dea00a863bc6d927f5de9e7f4f0470250eea92e41ad6f95b1ce578d520837689a381a013c785e5b2ccb2438871dfa0ba113c4c4e878229bc2eba6c9e07ff4b93f6a752a0e8da3f1599c09ef8081fe4c747ca17126011d399ae06dadfd2f07c87ae91ebe4a00ca53bbb4ac09a9c3472026da44c1171cd6e81fce0589ca82ad55728fdd96189a00968fead6c4b59be57752d7c857f7c21870f043a65ca2affeecc6902e1607046a05c10bda0c9f478d7f5498d121f84d49f779c81f4e7b9c0049fdcb74fb70b7a03a051560d91fdd24aded1648058c750feddc8a2b1212821f738976e8c3311504f0d80b90214f90211a04731c84bc72cae1c66b913d0b82b653ca881210063bd5dbdd131e29656958eafa014d01335b604bab03cd420a5265115a05d5b83d67e1fd1a62868dbc1f14fe5e6a0e4564e5aab39be2bdc1f62137a6b045918be45ffaea6e1d308a944a96ee20875a0b47fe19e4e2120b25d190bd348894731c5ecee3a588e4a822f69d2e7c9b50131a07d33901f08f5a308d3a55a31069ad4d63fd876ef67e6a8de3a57c64d27929c3da0c5cf00a7c0f6380d268ba53c76620b25298254175d000cadf4e5d29e56273e71a08bb70caa308bdf51e95c0dd70b65d864362b01db0c5db76ce04b7b5004270fb7a055a5af4f24f2b77b857cbd291f476e2cd550c915e70c2ddcd64298e103163bb4a0578e0aea71b399afbd8ae1e17aa5cc8f77842bebaa94ff56999cc136bce4aab4a06f5133ee07ed7fd0e015e00916e4f93174a5123f8514e575bf1a082354b08841a07e503baad00847c649b70c65c92e2655faee2ac452c8249a3713a5ac7dec3657a057966c2a091f42a98183754e671f4fe1e7c0fc936b278b275a6e38779cd9a837a0990b95d991e164ce4ed69312f778de382ed219c23732182f23beca1546f4708ca03082ab6a23286e5164ea50e76b5c33ccf0cad7a020078e88111fd4528f5eff74a0c632d9b3ba3ade07e40a45deda9552f65b85be5f3fcd0f3c4b51858123fb8164a050c054cababc246d94e7da67d5744eeef84710786d8796974880eccb862918f280b90214f90211a0e3d07a3ee996049406a96e5634c6987368a72da56fedffb302905577be52f653a038f224752fb8a5270ad93dd38af3d59a0e93915102b78c9c93bb9f281e235743a0413ddfe31d7aa3de0cabaaff63d8a98cfafdc22ba293d09bf6422ba63f766e2ca0f2c290a37b181714167bd5184cb9643ab66097c697d91f34cf234dea44e6f750a03d366d9d2a6406091e33a119f25a19286446f443c71773d49b1a2bb2351431a4a0efb7379b5816dd4a786d295d44b2437b32350b7207dc871b9bf2cc74c0cec2fda0037235ff3f9f9c3486238d974408d013ecb47258f59aba57ffb49f9b9fed3e48a0833d1569348dcaf135ff4df6df498e37aade7271b02d97d56902161b1933033ba0afabccd26a384fce8a8e8198fe75586dcbb360391556d1cf9cfd88bb4bf612c9a0c9ac063ff018737f620866c61591884b24665b17ad035feb18c8e924db60e067a0d6d8d2212be4f4a38b52f70537124feeb98fb6c9ba3b648b0e06a3790d418bd7a0da1cc367d15957ef7ca31b1f64d8bb9954e20ff9f5c2ef826358b85d9545bd38a02737017875dff329a22fcedcf467701fdaca0ad15abb55cf7ddf8af57f5da0f1a0cd29ebaddc43a10f7ea01ba6dddd579de72d98f7ea986450fa47b5053d74bc56a0cbb3632bd50b02d42a10a39f5fdeede90726f53650c26ba8c1eaae4e14f6129ba09b3db3269998e762b7ab9d8db1bb586949bab9168178401fa4836891fd8b4d9d80b90214f90211a0870443432dd3c88ae1cd061b55735a9d4006c9caef9ff658a77d11caca332a03a06c81d6d6909ad55758e34c1928338d45edd08c18a3824dd5be19e5b0f76aeae8a0f3d7d9c75deef73a66c0f0c7eb46eeafd71f5a45fb53533cb9056214465357c0a0df79325039c097042c8a59cb6ea3082f0a134b1044b3ae2ee3d011436a78525aa055ecb3ba960c4e12d138847f2b049acc74fc1811075f9ea40aa453fd4eb04f1aa01cd406b51e8d97dc8c39a91e9010c8565943f7b78825dcd9b099f77115cf898aa05cda1178cfe03cd5244deb6f8b81a32f5fc8dc5bb35ec51b4ef5506f40bb8451a009bc2a840f5545ed618e8c23a07ac440ac60cbda300aa4cd603b0a5cb8d36d45a0e1435fd8305ca188952be746ccf432170b9ec6e39b72300abd9f87a80f3f05d0a05056f55dc7549b8bb228b60021182ff831a174cf6c91bac066e8da8c35352a5ea0fc231a67ffbf9468eafe92b60c6ca098cf730cf84bc5eb64797ffc4f3ef895fca077590fa436fb509072cec35b9967c39fe84c8b46e66bdd5f0a2bb162a4c17334a0c94b3eade9fc6e80ecfe8d6c218d008f61499db34ed1b87d0288831233ee4f30a0bf25cd7d2a4e3f81674dd0966fee56ba3538f243c1278b460742407af6694afea041872908fb8ae707d8be2570789ab4a9d3a4fbb4b78feffd321142163f9c638ea0fd04d3195c8931ea1887ef2a2ceb48b57db06661591ae57f1e5666be6719533980b90214f90211a0b20eccecf05393549d549ef53fed7d4bb8aec7aaf33f07f03ff904577f15d0a4a072b641b2b7f31beb81389af9abc00a17f6f46e25b00b197c2ae483cb09cbec34a0c0a457b829be026c5eab6a5d5c05aca1d711a73595668f7ef6749c28123f0737a0a399ed5370e18117f79af215d6edb36345b7ef57650eb7f15fdf6a5d73ae84a5a0d89b0a2ecd022d81040fc2bd3f0601a8faa205bf68b327dd26176287edfc9685a0ed225ee0071eb63971ee07d49943ceafb1913b30552431adeb94bc164e98e354a0bce7cd3e620a2eb36751ff3cc4f003574fc8579e58f94028eb1b60128451a5fda0c010ebfb8b41f7ac8b73e64f7f7f2a32077dbc7fba53f82e266a2e60cab67c67a02d0f1e4c07f3879e944d7cccf6aedf45e0a624fb342113207d2c653f987fa745a055efc37c3c42964745741ea4cbb274ee6d9b2b210177d1e6e7f65b703e674eeba01d53ac17689ca5a1044840700bd7aeed4a1cf9283c3494ac69e15ae95f717172a0e19d1f940ed2502ac3885a6f5764ef88b6a90b1ec11482203cf2668ec4b64281a0d1ad9ce8a6ec214c5486ba23bf1ca8e55d678fa642bccf0446c31ccb41b37c56a0d824203770af36bf9a34f8e315c7466dd296eebf35bcd9fde77b45a1a41d71d0a018bd33ef44286c485576157e80a7931f59d683075d9be52330a2e485103cb433a0307b0062f8212f02e50d898d6b15e2f142db3f7d6b09f5a82634aa07d6d131ef80b90214f90211a015053ec755f353671d3dc4d18225e20e0df19f507e5e818e7c90e3e55f7f38a4a08a03395ed46817cabb87139c09a3afc2251a754edc923f44a837d61d4268562ca040e3c77ac1e58082620e44cdbf12a48b3e1ab1533f9dc524478a601d630f98c1a0437a29d8035566a7cc0936e216502bf429f374dc842249064bde947c26d3e4ada0768bf2a0bf611fc41459610e010943faf6c3077d6821c418c1fff24c34f9a303a03b7b929a6b636c33dcae04abed5493cb57d1aea8b0a0f74857ca80a8ae84cb4ea0d8a234ccc176f0cccad61f39b9bc41eb667e3ceecc43fb9b3abd15add5901abaa008c773fb9ec43a8098a2a892f0274258990d7b42dd7a8dff94fd283bc8d21e18a0e9feffb9d0f0361d0cdc5d346e5f4dab41db966672293fb7de57b7a69dc79bcaa0a80bb8362830027f68341e97df5e17312faca74de15751f51d6a47a4771d8270a07d25b6c1715665d23c83e338dd6cccca03e926a1038ed9bca7610d2c557f70fca06918ed8758c5f9ab421a1ec5742261487a429a431325e49ad13d7b960ef1d6d3a05521862e6b0cafdabbaed9a47eac45edd57fc47864e0f1b8c616a59b4c1de4f5a0e008856a527268381400bb72c3c7aa43360bb9520c1d7801a453d017c0b5e7d7a0d63b71b37208cdaf2063d567530ba98caccafe47eb12dfdf8550bf1bd02b7acea0b266e0dfb62a29d44fee021b72e494f69567d89349f470f2058d1690fa4fdeb880b90194f90191a04bbd53f85b3d34267d52c34e9d9c3a7d07f3e8cf88db3470f6f7c0520079fc88a0e905943bcecd064b8ca78dfde76025bcf705e31cd543708f2feb2af8240c6f178080a004bf41e9df1c0cf8a6918d00158a9bcd23ccbc4f976d98d31a23e39fc993608e80a0aa5123fdd7b5fc3a4ab3dad9c0d43e482c7bf5620e971121b36cd157991d5f69a02eb2676b9fd590e20b009623d15487841c91f2bf423f3232cac7df3914a4aa68a00857cb38c9918d39f2efd9446b8a8c07b4c506f361eec5fc93d9113029837f6aa031ca65f2ea15040ba97dada2b9f44ffd1241f30822a5e18f45b1c180128b36c3a0f0bff8824b5f2812506e4d11ac8d0983ca34d860cb884613bc0b760d83f0bde9a0098325c69c13355211062c7c9f7796513b7202956c2fcdc699dbda7b148a1c07a0d24e01fae1e1b40eb4aea1f1ef86f1f921c25a2f29224ef1a5ed41ccb9fda409a0afcca1659194c56d2ad861989d84e959c9ea8a96c596936b21a8f744d0e2182180a08ff1c39437bd2b9396b99c61f4c4466ea6e514ead089112c61129f6f9812941d80b873f87180a0d6382232c80f7b4ed2dc7010e507022697393873b96bdcbfac0b6893a71126fd808080808080808080808080a05df95487004307ef1a9601aeb9db655b03695f2f1c138f024d3a8c86dcaa12eca06fc57bfadc0b9052c65161d60a9c6e065d484b4703fbf85e34039871daba801580b868f8669d2021acc6973b430f67a259fa89d9d7339b25410e57ee37e383ce3900acb846f8440180a0248b0d54fe18d204c8808d3653dd4dde588dd1b7596fa85a06ec93000f5e647ea023a1472fa83f7542cf6eecb7637465cd72aa2470d206dd81dcfe9d1db4e8c633b90819f90816b90214f90211a0da3b28074a2e172304b6e137077ee0a40b9b34bce993eda0151c5d367bce5601a0b0b2697fd06619016070e3ad88c43d494b91a6ebf21ac28b9d50c9bae2e2cdf2a0fe4e2e5a068363f8be4132552134b9190f70037ef93dda015a662c196edec6e8a0f43584bcb1d01b07bfe535795803ff28ca46d5f4e84c36da12dd703ddc672a14a0a7a5b933e2e552b528b41a343a893f4ae6f97c36a580e45674fa281e925c4736a014fd8b0433c07a7da6641634faebbad9607a794a0a6bb399ae36adf067176802a09302c1cd93b6414e1893633f0db804d6251b250466237541e403e5b5750024dda0adcdf159339700d0dd36735127061c5275eb7a342901ba62a2d09b9e33ddc400a05e640ab546f22a9f95f7d4a87ce8fe36f71405ecca642259214b3ba5c66c12c8a0874a8a53cc5a6b16fcbaa4a9b0e63b4189543fb0da19c9ef4525f41514696d4da053ccfe6aa85116c1f26cc0937f91d91ed6733ff9f5af4e9fbfeb7801c78f80c2a0fcbbc0eedae9fee28a79861b9869d0a16539805d0593e4ef921b5065aea3ecb5a09f22e9faa6be7d216485b255f7e60d262b2c685d7cc84882c9989e73efd1fccea09863cedd6a18a515b4d056daf5ebb9b9635f969e7f00e09dcc6e255207a3f884a0e0f1e2f98d219f9826d23941a33b394edc17efd183ba41adf7d90997c7bcf0e9a0bc4bf073a453238a39969a5b241b26d13defb131b8e702ff324a17e7b758601d80b90214f90211a01380b0275551e583d7c05c627b1d42eca3ef1d2eb09dc4c36bb64e3a76660f50a0dbde6005d7711f3b61d0e99cd939507b00c993b2095e1eb4722e889ca07a1f4ea0a734333088a010cf7d8367b7acf5fc80c130b8deb14cff1310568a6dd4f737baa080556d621fdb5b6715770c2458929e2a863d09ab7d8f6699f7cdd270e47085bca0b84af57943ad82f48dd53d6f34a41236b7e93a73e0e5459f4c7edc090911fc06a02a4d34b22318b32dd57c1cf593f1e1134867c1f8a03afbd2ea5bd66f6dd47482a0a0291879823616ed9cb3192633ea3da7e03bec1f63b223ac9477f267df13835ca071ac5964dbdc2d8f5d28b22e53d50a308f3146cbee52b8bf66693d9ecbc5d5dca0020b010798b27ac9c8505ef7d2d63db17ab2be4cc067b57975d166e032de71faa075636c53017cb5dfece3b30783a012ec4d79b7b229d16725a5e3f191dacfb166a03cac168899a4cd9f4a13bb7a9e0486c2ab0333e7463ba416202a766b186fa9cfa08b6beb9ec3a968c76cc638442641f71b2e39354fc4b1494d290a720ce177a013a08c53756bb72b6a2b480a197df5f87f22ec37c4a0607ad5070f9937e9114e14daa04619456fce89a7a1422376ea97392ec076d956180e2bfc1f3d4b332f5b7b11fea06ba7e9d62ad737442f83910293780a8b998179840b79f642fa86c3c324cf923fa06c1925c3c2cb9fa3219c6d566d6010db4d1d8e06f187e41b9e1adeaaed4ffff380b90214f90211a014b33831e70b59dbdf5ad1e4da3eb079bacf18ea4af9429f21657443d53a03fea083deb70308c91ef54d9cf64eb036a5fb2eb6a4a66c038f900bf02f0158d58f54a0ac9348852cf7fece361021727d124a8a6a5cd29f72aa225a688b270960afa81ca029861daeb12aec910848f86c3cadb7ce218b235293159df77cda1f5076033c20a0a278e995d94b56e7446e798f7f9a0bace260b306149fccbb0bd2f0bea815fadba04b2cda24f602d76993a0918bc0fc351264b5af4e8e29dfe59004bfa11881c9f2a0d3b0d62ac486f3665091ce704b27f14f5a2975901da7085d4b8b9f97398cde69a0425e4c8f392675d874a14cf394dad418a5d8ef74d12aa378e65fb353acea3c75a0ef15d3ad0de9712888a500426de15c5dbb293b6e7e612e0d63fd103e5fe9f242a05cf1f8b1abffba75c1e0a4a6ca989cc3df5fd11d9501dc3b300001af89d1b0d3a0bedec59fb984bc9170acfa029950767917683c89b42b8d9e5cd71f563d4dde8fa00c21c3e8cbe64a039e4b063e88f595fe9abe6394693e275cab36ba69e34da3daa0ce27130849f3c2624dfa4059e23b7d772434d7cecd8cf433d1f0e0234724a916a0a5fb5a5bd4b06818bd6bed8be8b16518c804113dc1d29fedd9eea4117fff1c6fa0902e2486ba0142052db7de7a94142536e67d2681f8ddd5069d2ace175b862effa026c577472a19c160b65f4226a0ef3ae2258c44da6515d6994c3dfffaa8d488bd80b90134f90131a045b91eb9e0b787d3f24c7c75e4131baecc680de5fa12853292f7e475afb4a07d80a01960b3c91a1659e9fec9bc1003f03617be73d705a059d0f6e97814c391799bdca03479eb4213614eafd199be05a9db0c4bd2fcd2e4b143c9c11425b0e946da64bb80a00ffa2e7b26a8662c377a0f23ef81fc98d85308a2dea34683170ccfab4d0bcde08080a0adbcd0226d65475946cc8c99e78ed746a35118ac489ef6d34bb05d4be45762298080a00b06cf7d1291294d70c81046ea02ecda9c71d5f87ec2b1e2efe915f53edfa86580a0afd941cc1558fe2a35671aa9bb187e8b702e4b29e919dde9d6b0a505d877ebbfa044e2a0c52af887566de6647ad2b05e8e6b691c6b1fa69a94a63ab19e3463a4eda0290b23ffbc31183989b6f79663537a35d3dbc3bd195be4b50fc4438d52ea3cd780b853f85180808080808080808080a0c2eb48d478a6d247d605498dffdfca8a92d124f94586d17894819f6f7fa57cf280a0154c0e54e2afb5d83585451c826677adfa2850e53f93b1c9c80c617317d414d580808080b843f8419e32079f62ca174e3676d91c5a1d1d747104ae0a1d7376e8f1d50c39cac495a1a00b19f941707421a97afdfe5a8a800fc3ff43f28a16b5382eea1026ab8986f4c1';

    uint256 balanceBefore = IERC20(bridgedUSDC).balanceOf(address(bridgeSonic));

    vm.expectEmit(true, false, false, true, address(bridgeSonic));
    emit IAaveSonicEthERC20Bridge.Claim(token, amount);
    bridgeSonic.claim(depositId, token, amount, proof);

    uint256 balanceAfter = IERC20(bridgedUSDC).balanceOf(address(bridgeSonic));
    assertEq(balanceBefore + amount, balanceAfter);
  }
}

contract ClaimTestOnMainnet is AaveSonicEthERC20BridgeTestBase {
  uint256 depositId = 83107629666763039256896161050088999267967285591997717212311752767753133146999;
  address token = USDC;
  uint256 amount = 10_000_000;

  function setUp() public override {
    super.setUp();
    vm.selectFork(mainnetFork);
    // https://sonicscan.org/address/0xb7bd405f4a43e9da2d5fbf3066c0c28e46f9306e
    bridgeMainnet = AaveSonicEthERC20Bridge(payable(0xB7BD405f4a43E9DA2d5FbF3066C0C28E46F9306e));
  }

  function test_revertsIf_AlreadyClaimed() public {
    bytes memory proof = hex'f91722b90f03f900';

    vm.expectRevert('Already claimed');
    bridgeMainnet.claim(depositId, token, amount, proof);
  }

  function test_success() public {
    bytes32 storageSlot = keccak256(abi.encode(depositId, uint256(8)));
    vm.store(bridgeMainnet.MAINNET_BRIDGE(), storageSlot, bytes32(uint256(0)));

    bytes
      memory proof = hex'f912f3b90ad6f90ad3b90214f90211a08a99e2652d0adbfa3060aec132bddb413a87c6d923fc2da7ec5b30015b0e5dd6a09a610c427161926c002f983a9ec6916c426d9071ddde25b007a117b52178f520a0bf73a8d457a4c0f661ac38a5dbc01a5e3cbc7fb5771c8bb0fd6efaf22ce925bfa0dea63ef1f993fa9d271dd4386c3cfc3491052fcbd9446cf30e079e1c2c878c19a0f526c39d09eccb4b4b5ef88e49f68dbf79a3685698f9179dc7dae302d0a6fba8a01d0281a03921293f6c4ba8040bf821c7acb0bd4e41668477b321cc7935888f18a0e466bee26c7f26c98541864ffd7121484e2ac47f95ec780faae23c600726013da0e480c3d8122a060b330af3a43a729bd9d865b52ed99acd5d9d73ee5ad28d8e5da021d17705797b3bb83faef0a319aa4795c5f3ee757d5fc7f6b7d88a49cba285eaa059d5df2f7f89cee8ede959f315b9ab4c07953a0795949337274caff7bcb4b74ea027dea9600f0944792b297b7e1b92264d69fbad4e4a5b89194fb922e148522924a002931c20884d64ffad0f33fc1b3c33731fb53e41e36f286acf6487efc044136aa0dd2ccf8c9717ffbdd47cfbc40ccb8558082b03781a6a01c0d1b2a35eca1f9f97a06a9ebb5d0efa7c0a6dac56a42ebd0cdf72161dbf810471dac0c23bb19d1f3fdba0ff0269b16f29716a73eb79c97425622830d06867d6fa9547c6f4fad374501d05a0c121ab9901fe419921e4d183642cd9a1db9c915b66a59bd7c414cfcb9c0f46f680b90214f90211a0541925e5f4da3d5d349d2f51d36e954620cf3d93ae81327307e639da09fa4c46a002af0270c9742124f0a8093b4cd1be83f41d790f1c6351d461170eaf954b5bb7a0449a5d4e6b7e23477ce607cbb3c591d04f7a546eb14ad37ae6d63f5643eca019a0c166dfc560ae1f19ea4685a49d403dcfc72965b519b1b57aea7f354a1bb29e32a07c751c27c9e1dcf1a3db1c16ea6577bdbac6a5255d260152e3467aee0719ec11a0140ca126dbdc15e1af8f847fb8f07bccc11b4689c4613453eb06509baf1927eaa04dca92700c3ba89752c0151b78706cd6f9d7ad48c71f19fc1e1aa351e7cde70aa0a3f0e77550caff458cae080750d814744c3a0279596b46e3497db1efdda92a08a0f885d2f42409fa4e0424044418cbfdb1b7e3400ded8c71b9d74616a1a2ef2d0ca0180776ff0b981fa45899c935222fb451ad2faeac2a3e2ce8f926cb5382c2a1aaa001ac0098d7c99c2aa3fca371bc3123f5309446dfd43f0a502bdb70b55f84f39da0e279bb298267ec81fcb66badd7e83429292245152efa94b9bfb1877db30c2c30a08189021f1c32f6dcf7ad77170d76531d2aa3364eac6c1561dc08cef4b286d031a0ec8cff23643c09cfbc63bb27a7f1f35a64cf195207a3a1a2c9198866a8224ae3a00edc79a5c0ba042dbd5c273dda9dd97c9f6c791d7fe174d258aa7d0fa7ae3ebda09400bfb6d70c03d9d2c4c36227ffcd26b4f0bd562e173ace58839461fef8f3a380b90214f90211a0481a2945645f6e260869e8aaef95df3cbaf6faee52a36744cd8e596ce945fd3ba011cecb46521e0eb67fc9237da2b62c8e2384e7313bc150d33ed952b5c9a637d8a0b124a89319c664614842a9f2872d38b81e3e7da56b466516ac7b7ae9e512f68ea086e76fe7fa1a999d6dab308c92ea6821311e146efed787cf3da18173356c30c3a03e0fe29c7a9c586d52f2a679bed26e2b3ceb1182b771e3abf269b8e52013b8bfa057e7164811a2d67e72c964db839709c2315732d8db2ee178c5e106895936d731a05a1637633d465983c89732ecea904b6e73fce9a1d5fe7a4c4230935f98c2eb81a0fc9cc22b52db834fa49346660392b5fb716f7b48083b7980f25af5b51166f4c5a05424929cb7f0bfe836abc98fdd95e1d2752387144b84766dd054a791bca8618ca0ad19f03cec580d59c543f267aa0127a7b3c63fbc979e14da282cf85a587d6e76a01bb8ad48b1c0d47bd81c5d3473a8bc19a1be40cdd7c8c893f8aef921db1d6641a00bc068f5a4b2dd4be8600f9acaf6a7984af1823410d2db9f62f02675fcbe4149a0b153a23a3828f2b41795cefbe65a9acdbb0e9f2a414f240ebcf21e19a6ad87b3a0ad0ec9af5d3b82e90036e74aca2514ba18f2b907895deb4852dbdec20e9f6283a00afe6ab8ab86084ad001cf77b340662db83ed28daf9bdfbefcd7d93293ce6611a044c962b96550786d369cbf8a48903c8ed1ca15bab4201e1672ac0aa21856525f80b90214f90211a060557f018a5f0978dc7c47bab82290f45bf805851a3da52d5ab7ea9f1b8e5cc4a00f58c924541581629c5fbeb989613d7c0bf05dbc4f551e78d857772926399d98a02cca4aef3999a3d652e27aae9a3b89c5fea78cdaf814584123b4845eecf70ea6a08f97921028d43fc01cfcb48956d93e26f3daa932e25951c4f249d103fe0911cfa0707613bb9a99dec98c1562fb00bc26ba086b58b1327bed3113be1cea5988c99da00bf14d97524b5f4f581e9306c2aaec15cae9aa97d819cf9fd04077723452a466a05d80fe8b37317a7dfd8c7808c517a0799b31176d418170f114d8799e102cb208a06dcc3a7cbe3a9218ed86ec23430f12fd5e2ed3cbb5c0ce938c4aeb78b6042b1ba077b244e81b12e33ba7e45f1e83740d7ef0cdc2e2b5f38db6d7eae2151c9fb7ada05f50d37a67f828a1731abe550583f5bc2ea899a8c57c4ea8a773ea77b47ed896a028448c1d380b5ee13179772ba9004c108d5eb1782920979562324c4fad71e008a078d73a6b9ababbad001ad949df082d0776ab3c35efead520188d57e9bdfd3c9ca0d0aa099245b6beb58cfb7955216073c71f9addc94cff32b8092b273279a68524a0fca399fdee2e47423e54495dc29f0bc440bbfee60d487984e19e0627f2a8d1baa027628f62532f6089825f1b90010d77f9253770858d55d2b64b065424d0e80ac8a007bd787827ccbd234cf77ae4cfef73fa0c42abb18f7a546d1b94bae96d34155e80b90174f90171a0e7862924bbc3b66bc42bebaa1ae0ec759d2872dfc5c9b3f1c9b0adb9faae9eab80a03eec81e5b7b4b4c5f8c24716deb93ad8d50d264e680548f918f96db03c06ea10a0383aac960a850d21aa14eb8aaf2d211b5c9dd6d626699048e0215543084df1d3a0c262c372718d771de823f07ded073ca6e17f69d365b1b58e77b0016274a2383ba0b613ae1d73221bec4a7a4584242766a0368dfdb1d5974142ba31958cd16c7b1ca0917ed0fddbac777650a98bf27bdfe2b02b45e53e6ae359ee865702e90d04ff758080a085707540e5048e1a121600ec8b10f7558b1f338cc50caafff4ce628fcd5daf45a0b25795dbe902e1de67df6923084e34c871e2678df345ed18e56717cacaa81808a033168d8bc9988f2b8f1f49cf53e1034ae0a8cd2c7781288dd77d69972fbfeb97a0a3db659fe92a0ef8ebabffc7e1722830f8770297fd2c80ef305e81e9ca0acbf38080a060a346d03f2781f2b404903ea43ac2d7e859ce29af517ce243bd6142c3f4920580b893f8918080a01f950df26460d066843a1a7e4463c73041c060fcf893492384c35f336ef1906a80a062776ad60c277a9605dab90adf3acfe7278d19d0d60930a7b430d5c2259a080580808080a0cc1887e0d0f2250e910dd30aca9901268cd5ef79a25486fffca8860125ab41b88080a05f3d7593526e70fc61660b1c3f79a6353ac3b86b5ae1d7b09d8dd7168ce3a52180808080b869f8679e2061b10274fc7f96d7573274e22115b0bf1778a3dc5b13d9af443fd73a18b846f8440180a07fab8c56433b83012e33821d6be76c60d633cf21f09f78af31d97f9887df523aa023a1472fa83f7542cf6eecb7637465cd72aa2470d206dd81dcfe9d1db4e8c633b90817f90814b90214f90211a051e6329539ec18e0fdd885126a57bc34a7f5b7dd1a088e9d6d980d32bb2de1afa06ecf382d0056493ddda8a07bb43d79bf98340efc7d329cd3261a8bcebfc0ba7fa0f5b5624a558e41e302018b941a8d0154838c8447c8355493d98caaceefc1873fa0852e87a4b6d745fc7e90e8e35bf0f3a3cf3848a673a1daab297fb50da4d8fc8fa00556e84deb7cb3cac77fe0558cb80fee9630249aa3a71f49357e5ef4b961fb8da023cbb1167233460582fc8f0c7313b554d1fea2174786ad5b82a190ee560ac7c1a0380c7b22edf773d403bd18c33398dea1481bb8166fca40c4524d6f00dccf4ed1a06462a23b91ffca7128811da8988bd564a7c17208e7f31fe71711460a75989141a028a6d3f3d03cb0055b69004a846f0bc347e2c33239f275378863b7b94cdb7ac7a002218ccb954ce706e97a26ec63fcc2da97fab015f2ef9d23bd2a00b397a07e99a06306d11cc9fcb50429474bd21398d790958835905bb4cc14c50570f6000d457ea0feb7be766530d588a888e22837da08b86042f6a612ef5fec7d26718d49e0d048a01f499aefe6e61092eff2cd7a7795bd230fc9df74dd74a9f1bd5f83c56dece8b8a07a031f6b0329b88ad11b9be7a8c8922fbc3fd51cbf02dcf9940e81eedf0f05d9a06cdd118733b3c2f3e619687323cca3ed589ddfbf7a4199feebf0ba719e4c7fe6a02be2700b0d74fee33549510f3b3d66491e513d17d5a84797c88680d68f6d2f1a80b90214f90211a0ad5a91ba5e6bda4bd91ef19c3b886562484dfebb2ad90501ea5c8a097d55cf22a028b2c4de1ad2857ab4297f0f371a604dea22757242ebcc215cac82a872dcd9cca03483ced60fa28fa33bca0b642764670316ea5e9cb9ecfbf2bf4067bd66a62b12a0cd5850f4da686071e06c4e4608ef160d5e1162e419448ca469d9c39fec607289a0cd9bd1c2eb6c1726c52f13902bb9c6f340ddface42dd304531acd1d62d67b3eda0670da45aa504fee47df0ee5dab2cb2eb2b291bac9e8f6d954d99a431dafd7172a06408a43131beeed5cac650169d02df1ce7e9c50d7d86f7a9dce3339ffb93aa5ba0fbf2a0ec965946a6dfc86af154f965db38d8c9383d6e7d335eb167c582e2f0cfa0fbc0514847a20ae63ad0c7b7bf4088195713486c15ae426ba5c3c59a7cb021e0a00feafdad771cd83db5b08fc307357741bb57e891772582bbbeb85874e1010d74a015b08a1722df3998ad6f5d67d2fa35a489101815c782d7661a1e2bbaa95966afa0c510e915d96920561533a9b95db524d598bf0ee89890fbeeb0d0ba59898289fba0a58f287d5b35fe1d2365ce764fd9e1149b8638b4fa784c7d66b6c2381e2afcfda021718a5c13cc975cff8604cb8fbcf8e39e8c7ce3f6d0b1c8ac89973e3128be86a025161f1fdce03ca0ab6cff538b80203852d793e1b1c2aae07d70364740ee9219a0cbac90fb11218c21b7f883deb21077c64aa002e85870923bd9032669c576c3f580b90214f90211a008ef1d7ff43df2aeee5e5389ed6eac52e5e7aa6a0dc97d62eef6e48a77b302a2a0ebe934c65315fd8ba1508b2be2c51dcefa6de97691ffc567ae22ec93c165404da0060d0682f114a09ce69a6f3f37ba43018a06835a0755b0ea85e82be09d75fa19a0fb9d1bbcca007f3f9387440c6a0ec54cf1b82e92592b34eea25ce1652f30d76fa02ccaf25b3aa55358778a4f98eb79cc03750991fe24421b16d63f787dd310622aa0234697810345345f0f3b6bfaec4a77ae715e9a79fb55b003c6f31850c46b982ea0c6fcc047cca6edd4fb1ad3717ad9715fabddc792c4535027de6e79e48b358a28a023c3d95f39d81132bc8107ab0144347bb7f52483eacd97d2fed6d95ccb104fafa00fa4a6b7c00de3cae21ab014431eb2ea77fe5c573ffd2eb386b6155d1f3310a3a06ba97a26ce85f204c68677964af6621a9e4cf62e012eb105ef030e1c4f86cf0aa081d7ec046ea56bf96a9f1fe2984a0c0287ae2a6dbf63c3b7100732ff9cc2378fa088c12535f264f824dbfcb2fbbc77b964f68dab1ace78762af7c948f7c4d93395a03073b1e447f318ed0c2dfd8c3484a8728cd8ed1ae6570bc5d5673035918ba02ea06ed73a62e699fe0a5b64e1c2b071af7e88574f37a7c913f76ff3365028a5cd61a0ef1a129321a95336b6e3917438875a52c6ec2de459e44b3d61718c328b5a9a6da0ab34ffe451b15c8b9f54d3d96f7ae4fde058167cfdf96a42c8480db227cbb55b80b8f3f8f180a031e1f8f26fc7831987b796e27d55c04315c5ccebec546fe0f184319365ed9985a0fa7da8124c7902526a2ea7fd441fad1cc854ae4a9497ae0b0fe3b2116402893080a070f6bf952c2006c990523c57c974ad82157d137a526b0869a00c221fdf12a0fb80a0f1acfc6a37c1fc04f6555a508beca0aeccf24bfc8bddc11c1fbe474090fd017a80a0d97c95e49f77a3376011665a7de9fb01c40778c6c4d5a52d614ef1de9e4f0ccaa0fd4d5e4488dbb42f91317d3dd2ac8a359eff4588ae2dc4227d0ee01013203ad9a0823f7e05d0cd641d97921569b9278d82d7d0d5d537da9c1aaa17c2954810ea25808080808080b893f89180a0c92874d0129f383b08a875f076c1c755f181a38958cc7d5a2bbc7958bab47760a06af583d0be9c31bb19103bb2818245f42c4d1f7b40919760834deff9b9cb1169a013118231310df21303137826c76789a88ef0060dbc51d438e904b009b466ce8ba0ed98b0f90c1e9fd449ebf46e451add0218437a0ca82ddffa4b28fc3e52ca167a808080808080808080808080b843f8419e34926ecad9836ce100b24b4e1223ba68aa8c8e33b43aa545ce703ca948d4a1a00b19f941707421a97afdfe5a8a800fc3ff43f28a16b5382eea1026ab8986f4c1';

    uint256 balanceBefore = IERC20(USDC).balanceOf(address(bridgeMainnet));

    vm.expectEmit(true, false, false, true, address(bridgeMainnet));
    emit IAaveSonicEthERC20Bridge.Claim(token, amount);
    bridgeMainnet.claim(depositId, token, amount, proof);

    uint256 balanceAfter = IERC20(USDC).balanceOf(address(bridgeMainnet));
    assertEq(balanceBefore + amount, balanceAfter);
  }
}

contract WithdrawToCollectorTest is AaveSonicEthERC20BridgeTestBase {
  uint256 usdcTestAmount = 1_000e6;
  uint256 ethTestAmount = 1_000e18;

  function test_revertsIf_InvalidChain() public {
    vm.selectFork(invalidChainFork);
    AaveSonicEthERC20Bridge invalidBridge = new AaveSonicEthERC20Bridge(owner, guardian);

    vm.expectRevert(IAaveSonicEthERC20Bridge.InvalidChain.selector);
    invalidBridge.withdrawEthToCollector();
  }

  function test_success_withdrawTokenOnMainnet() public {
    vm.selectFork(mainnetFork);
    deal(USDC, address(bridgeMainnet), usdcTestAmount);

    uint256 balanceOfBridgeBefore = IERC20(USDC).balanceOf(address(bridgeMainnet));
    uint256 balanceOfCollectorBefore = IERC20(USDC).balanceOf(address(AaveV3Ethereum.COLLECTOR));

    vm.expectEmit(true, false, false, true, address(bridgeMainnet));
    emit IAaveSonicEthERC20Bridge.WithdrawToCollector(USDC, usdcTestAmount);
    bridgeMainnet.withdrawToCollector(USDC);

    uint256 balanceOfBridgeAfter = IERC20(USDC).balanceOf(address(bridgeMainnet));
    uint256 balanceOfCollectorAfter = IERC20(USDC).balanceOf(address(AaveV3Ethereum.COLLECTOR));

    assertEq(balanceOfBridgeBefore, usdcTestAmount);
    assertEq(balanceOfBridgeAfter, 0);
    assertEq(balanceOfCollectorAfter, balanceOfCollectorBefore + usdcTestAmount);
  }

  function test_success_withdrawEthOnMainnet() public {
    vm.selectFork(mainnetFork);
    deal(address(bridgeMainnet), ethTestAmount);

    uint256 balanceOfBridgeBefore = payable(address(bridgeMainnet)).balance;
    uint256 balanceOfCollectorBefore = payable(address(AaveV3Ethereum.COLLECTOR)).balance;

    vm.expectEmit(true, false, false, true, address(bridgeMainnet));
    emit IAaveSonicEthERC20Bridge.WithdrawToCollector(address(0), ethTestAmount);
    bridgeMainnet.withdrawEthToCollector();

    uint256 balanceOfBridgeAfter = payable(address(bridgeMainnet)).balance;
    uint256 balanceOfCollectorAfter = payable(address(AaveV3Ethereum.COLLECTOR)).balance;

    assertEq(balanceOfBridgeBefore, ethTestAmount);
    assertEq(balanceOfBridgeAfter, 0);
    assertEq(balanceOfCollectorAfter, balanceOfCollectorBefore + ethTestAmount);
  }

  function test_success_withdrawTokenOnSonic() public {
    vm.selectFork(sonicFork);
    deal(bridgedUSDC, address(bridgeSonic), usdcTestAmount);

    uint256 balanceOfBridgeBefore = IERC20(bridgedUSDC).balanceOf(address(bridgeSonic));
    uint256 balanceOfCollectorBefore = IERC20(bridgedUSDC).balanceOf(
      address(AaveV3Sonic.COLLECTOR)
    );

    vm.expectEmit(true, false, false, true, address(bridgeSonic));
    emit IAaveSonicEthERC20Bridge.WithdrawToCollector(bridgedUSDC, usdcTestAmount);
    bridgeSonic.withdrawToCollector(bridgedUSDC);

    uint256 balanceOfBridgeAfter = IERC20(bridgedUSDC).balanceOf(address(bridgeSonic));
    uint256 balanceOfCollectorAfter = IERC20(bridgedUSDC).balanceOf(address(AaveV3Sonic.COLLECTOR));

    assertEq(balanceOfBridgeBefore, usdcTestAmount);
    assertEq(balanceOfBridgeAfter, 0);
    assertEq(balanceOfCollectorAfter, balanceOfCollectorBefore + usdcTestAmount);
  }

  function test_success_withdrawSOnSonic() public {
    vm.selectFork(sonicFork);
    deal(address(bridgeSonic), ethTestAmount);

    uint256 balanceOfBridgeBefore = payable(address(bridgeSonic)).balance;
    uint256 balanceOfCollectorBefore = payable(address(AaveV3Sonic.COLLECTOR)).balance;

    vm.expectEmit(true, false, false, true, address(bridgeSonic));
    emit IAaveSonicEthERC20Bridge.WithdrawToCollector(address(0), ethTestAmount);
    bridgeSonic.withdrawEthToCollector();

    uint256 balanceOfBridgeAfter = payable(address(bridgeSonic)).balance;
    uint256 balanceOfCollectorAfter = payable(address(AaveV3Sonic.COLLECTOR)).balance;

    assertEq(balanceOfBridgeBefore, ethTestAmount);
    assertEq(balanceOfBridgeAfter, 0);
    assertEq(balanceOfCollectorAfter, balanceOfCollectorBefore + ethTestAmount);
  }
}

contract TransferOwnershipTest is AaveSonicEthERC20BridgeTestBase {
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

contract UpdateGuardianTest is AaveSonicEthERC20BridgeTestBase {
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

contract EmergencyTokenTransferTest is AaveSonicEthERC20BridgeTestBase {
  uint256 amount = 1_000e18;

  function test_successful() public {
    vm.selectFork(mainnetFork);
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
