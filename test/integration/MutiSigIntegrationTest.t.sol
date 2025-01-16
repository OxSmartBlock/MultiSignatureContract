//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
// import {Test} from "forge-std/Test.sol";
// import {MultiSig} from "../../src/MultiSig.sol";
// import {DeployMultiSig} from "../../script/DeployMultiSig.s.sol";
// import {DeployFaucetToken} from "../../script/DeployFaucetToken.s.sol";
// import {FaucetToken} from "../../src/FaucetToken.sol";
// import {MultiSigAddAsset, FundMultiSig} from "../../script/interactions/MultiSigInteraction.s.sol";
// import {Test, console} from "forge-std/Test.sol";

// contract MultiSigIntegrationTest is Test {
//     address[3] admins = [
//         0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
//         0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
//         0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
//     ];
//     address multiSigContract;
//     FaucetToken faucetToken;
//     MultiSig multiSig;
//     uint256 constant DEPOSIT_AMOUNT = 100 ether;

//     function setUp() public {
//         DeployFaucetToken deployFaucetToken = new DeployFaucetToken();
//         faucetToken = deployFaucetToken.run();
//         DeployMultiSig deployMultiSig = new DeployMultiSig(admins);
//         (multiSig, ) = deployMultiSig.run();
//         multiSigContract = address(multiSig);
//     }

//     function testNewAssetAdded() public {
//         MultiSigAddAsset multiSigAddAsset = new MultiSigAddAsset(
//             address(faucetToken)
//         );
//         multiSigAddAsset.addAsset(multiSigContract);
//         vm.assertEq(multiSig.getIsTokenAllowed(address(faucetToken)), true);
//     }

//     modifier mintAndAddAsset() {
//         MultiSigAddAsset multiSigAddAsset = new MultiSigAddAsset(
//             address(faucetToken)
//         );
//         multiSigAddAsset.addAsset(multiSigContract);
//         faucetToken.mint(msg.sender);
//         vm.startBroadcast();
//         faucetToken.approve(multiSigContract, DEPOSIT_AMOUNT);
//         vm.stopBroadcast();
//         _;
//     }

//     function testCanFundContract() public mintAndAddAsset {
//         FundMultiSig fundMultiSig = new FundMultiSig(
//             address(faucetToken),
//             DEPOSIT_AMOUNT
//         );

//         fundMultiSig.fundMultiSig(multiSigContract);
//         uint256 balanceInContract = multiSig.getTokenBalanceInContract(
//             address(faucetToken)
//         );
//         vm.assertEq(DEPOSIT_AMOUNT, balanceInContract);
//     }
// }
