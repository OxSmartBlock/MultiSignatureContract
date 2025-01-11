//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Script} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract DeployMultiSig is Script {
    address[3] adminsAddress = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];

    function run() external returns (MultiSig, address[3] memory) {
        vm.startBroadcast();
        MultiSig multiSig = new MultiSig(adminsAddress);
        vm.stopBroadcast();
        return (multiSig, adminsAddress);
    }
}
