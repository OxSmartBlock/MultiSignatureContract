//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract DeployMultiSig is Script {
    address[3] adminsAddress;

    constructor(address[3] memory _adminsAddress) {
        adminsAddress = _adminsAddress;
    }

    function run() external returns (MultiSig, address[3] memory) {
        vm.startBroadcast();
        MultiSig multiSig = new MultiSig(adminsAddress);
        vm.stopBroadcast();
        return (multiSig, adminsAddress);
    }
}
