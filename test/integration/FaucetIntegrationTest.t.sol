//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {MintFaucetToken} from "../../script/interactions/FaucetInteraction.sol";
import {Test} from "forge-std/Test.sol";
import {DeployFaucetToken} from "../../script/DeployFaucetToken.s.sol";
import {FaucetToken} from "../../src/FaucetToken.sol";

contract FaucetIntegrationTest is Test {
    address facuetTokenContractAddress;
    uint256 constant DRIP_AMOUNT = 100 ether;

    function setUp() external {
        DeployFaucetToken deployFaucetToken = new DeployFaucetToken();
        facuetTokenContractAddress = address(deployFaucetToken.run());
    }

    function testMintInteraction() public {
        address testAddress = makeAddr("testAddress");
        MintFaucetToken mintFaucetToken = new MintFaucetToken(testAddress);
        mintFaucetToken.mintToken(facuetTokenContractAddress);
        vm.assertEq(FaucetToken(facuetTokenContractAddress).balanceOf(testAddress), DRIP_AMOUNT);
    }

    function testMintGateKeep() public {
        address testAddress = makeAddr("testAddress");
        MintFaucetToken mintFaucetToken = new MintFaucetToken(testAddress);
        mintFaucetToken.mintToken(facuetTokenContractAddress);
        vm.expectRevert(FaucetToken.FaucetToken__WaitTimeNotOver.selector);
        mintFaucetToken.mintToken(facuetTokenContractAddress);
    }
}
