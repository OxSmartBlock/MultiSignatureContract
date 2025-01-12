//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {FaucetToken} from "../../src/FaucetToken.sol";
import {DeployFaucetToken} from "../../script/DeployFaucetToken.s.sol";
import {Test} from "forge-std/Test.sol";

contract TestFaucetTeoken is Test {
    FaucetToken faucetToken;
    uint256 constant DRIP_AMOUNT = 100 ether;

    address mintAddress = makeAddr("mintAddress");

    function setUp() external {
        DeployFaucetToken deployFaucetToken = new DeployFaucetToken();
        faucetToken = deployFaucetToken.run();
    }

    function testMintSuccessful() public {
        vm.prank(mintAddress);
        faucetToken.mint(mintAddress);
        assertEq(faucetToken.balanceOf(mintAddress), DRIP_AMOUNT);
    }

    function testTimeGateKeep() public {
        vm.startPrank(mintAddress);
        faucetToken.mint(mintAddress);
        vm.expectRevert(FaucetToken.FaucetToken__WaitTimeNotOver.selector);
        faucetToken.mint(mintAddress);

        vm.stopPrank();
    }

    function testMintAfterWaitTimeOver() public {
        vm.startPrank(mintAddress);
        faucetToken.mint(mintAddress);
        vm.warp(block.timestamp + 1 days);

        faucetToken.mint(mintAddress);
        assertEq(faucetToken.balanceOf(mintAddress), 200 ether);
        vm.stopPrank();
    }
}
