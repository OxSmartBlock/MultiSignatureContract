//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {FaucetToken} from "../src/FaucetToken.sol";
import {Script} from "forge-std/Script.sol";

contract DeployFaucetToken is Script {
    function run() external returns (FaucetToken) {
        vm.startBroadcast();
        FaucetToken faucetToken = new FaucetToken();
        vm.stopBroadcast();
        return faucetToken;
    }
}
