//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {DevOpsTools} from "@foundry-dev-ops/DevOpsTools.sol";
import {Script} from "forge-std/Script.sol";
import {FaucetToken} from "../../src/FaucetToken.sol";

contract FaucetTokenMint is Script {
    address immutable to;

    constructor(address _to) {
        to = _to;
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools
            .get_most_recent_deployment("FaucetToken", block.chainid);
        vm.startBroadcast();
        FaucetToken(latestDeploymentAddress);
        vm.stopBroadcast();
    }
}
