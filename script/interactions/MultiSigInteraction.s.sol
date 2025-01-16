//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-dev-ops/DevOpsTools.sol";
import {MultiSig} from "../../src/MultiSig.sol";

contract FundMultiSig is Script {
    address immutable tokenAddress;
    uint256 immutable amount;

    constructor(address _tokenAddress, uint256 _amount) {
        tokenAddress = _tokenAddress;
        amount = _amount;
    }

    function fundMultiSig(address _multiSig) public {
        vm.startBroadcast();
        MultiSig(_multiSig).fundContract(tokenAddress, amount);
        vm.stopBroadcast();
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);
        fundMultiSig(latestDeploymentAddress);
    }
}

contract MultiSigAddAsset is Script {
    address immutable newAssetAddress;

    constructor(address _newAssetAddress) {
        newAssetAddress = _newAssetAddress;
    }

    function addAsset(address _contractAddress) public {
        vm.startBroadcast();
        MultiSig(_contractAddress).addNewAssetAllowed(newAssetAddress);

        vm.stopBroadcast();
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);
        addAsset(latestDeploymentAddress);
    }
}

contract MultiSigWithdrawalPropsal is Script {
    address immutable tokenContractAddress;
    address immutable to;
    uint256 immutable amount;
    string message;

    constructor(address _tokenContractAddress, address _to, uint256 _amount, string memory _message) {
        tokenContractAddress = _tokenContractAddress;
        to = _to;
        amount = _amount;
        message = _message;
    }

    function proposal(address _contractAddress) public {
        vm.startBroadcast();
        MultiSig(_contractAddress).proposeWithdrawal(tokenContractAddress, to, amount, message);
        vm.stopBroadcast();
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);
        proposal(latestDeploymentAddress);
    }
}

contract VoteWithdrawalMultiSig is Script {
    bool immutable shouldPass;
    bytes32 immutable proposalId;

    constructor(bytes32 _proposalId, bool _shouldPass) {
        proposalId = _proposalId;
        shouldPass = _shouldPass;
    }

    function vote(address _contractAddress, bool _shouldPass, bytes32 _proposalId) public {
        vm.startBroadcast();
        MultiSig(_contractAddress).voteOnWithdrawalProposal(_proposalId, _shouldPass);
        vm.stopBroadcast();
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);
        vote(latestDeploymentAddress, shouldPass, proposalId);
    }
}

contract ResolveMultiSigProposal is Script {
    bytes32 immutable proposalId;

    constructor(bytes32 _proposalId) {
        proposalId = _proposalId;
    }

    function resolveProposal(address _contractAddress, bytes32 _proposalId) public {
        vm.startBroadcast();
        MultiSig(_contractAddress).resolveWithdrawalProposal(_proposalId);

        vm.stopBroadcast();
    }

    function run() external {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);
        resolveProposal(latestDeploymentAddress, proposalId);
    }
}

contract LatestMultiSigProposal {
    function run() external view returns (bytes32) {
        address latestDeploymentAddress = DevOpsTools.get_most_recent_deployment("MultiSig", block.chainid);

        return MultiSig(latestDeploymentAddress).getActiveWithdrawalProposal();
    }
}
