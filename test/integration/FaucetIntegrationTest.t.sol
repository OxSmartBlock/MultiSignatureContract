//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {FaucetTokenMint} from "../../script/interactions/FaucetInteraction.sol";
import {Test} from "forge-std/Test.sol";
import {DeployFaucetToken} from "../../script/DeployFaucetToken.s.sol";
import {FaucetToken} from "../../src/FaucetToken.sol";

contract FaucetIntegrationTest is Test {
    FaucetToken faucetToken;

    function setUp() external {
        DeployFaucetToken deployFaucetToken = new DeployFaucetToken();
        faucetToken = deployFaucetToken.run();
    }

    function testMintInteraction() public {
        address testAddress = makeAddr("testAddress");
        new FaucetTokenMint(testAddress).run();
        uint256 expectedAddress = faucetToken.balanceOf(testAddress);
        assertEq(expectedAddress, 100 ether);
    }
}
