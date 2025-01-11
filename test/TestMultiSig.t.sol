//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;
import {Test, console} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {DeployMultiSig} from "../script/DeployMultiSig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract TestMultiSig is Test {
    MultiSig multiSig;
    address[3] expectedAdmins = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    address[3] adminsAddress;
    address mockToken;
    uint256 constant STARTING_BALANCE_OF_ADMINS = 5 ether;
    uint256 constant DEPOSIT_AMOUNT = 3 ether;
    address CHARITY_RECEIVER = makeAddr("charity");

    function setUp() external {
        DeployMultiSig deployMultiSig = new DeployMultiSig();
        (multiSig, adminsAddress) = deployMultiSig.run();
        ERC20Mock token = new ERC20Mock();
        mockToken = address(token);
        for (uint256 i = 0; i < adminsAddress.length; i++) {
            vm.prank(adminsAddress[i]);
            token.mint(adminsAddress[i], STARTING_BALANCE_OF_ADMINS);
        }
    }

    // Helper functions
    function depositToken(address sender, uint256 depositAmount) internal {
        tokenAdd(sender);
        vm.startPrank(sender);
        ERC20Mock(mockToken).approve(address(multiSig), DEPOSIT_AMOUNT);
        multiSig.fundContract(mockToken, depositAmount);

        vm.stopPrank();
    }

    function tokenAdd(address sender) internal {
        vm.prank(sender);
        multiSig.addNewAssetAllowed(address(mockToken));
    }

    function proposeWithdrawal(address sender) internal {
        vm.prank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
    }

    function testAdminAddresses() public view {
        address[3] memory adminResult = multiSig.getAdmins();
        assertEq(
            keccak256(abi.encodePacked(adminResult)),
            keccak256(abi.encodePacked(expectedAdmins))
        );
    }

    function testOnlyAnAdminCanAddToken() public {
        address attacker = makeAddr("attacker");

        vm.expectRevert(MultiSig.MultiSig__OnlyAdminAllowed.selector);
        vm.prank(attacker);
        multiSig.addNewAssetAllowed(mockToken);
    }

    function testAdminAddTokenContract() public {
        console.log(adminsAddress[0]);
        vm.prank(adminsAddress[0]);
        multiSig.addNewAssetAllowed(mockToken);
        bool isAllowed = multiSig.getIsTokenAllowed(mockToken);
        uint256 allTokensAllowed = multiSig.getAllowedToken().length;
        assertEq(isAllowed, true);
        assertEq(allTokensAllowed, 1);
    }

    function testTokenDeposit(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        depositToken(adminsAddress[index], DEPOSIT_AMOUNT);
        uint256 balance = multiSig.getTokenBalanceInContract(
            address(mockToken)
        );
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function testZeroValueDeposit(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        vm.startPrank(sender);
        ERC20Mock(address(mockToken)).approve(address(multiSig), 0);
        vm.expectRevert(MultiSig.MultiSig__ZeroAmountNotAllowed.selector);
        multiSig.fundContract(address(mockToken), 0);

        vm.stopPrank();
    }

    function testNotEnoughAllowanceRevert(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        vm.startPrank(sender);
        ERC20Mock(address(mockToken)).approve(
            address(multiSig),
            DEPOSIT_AMOUNT
        );

        vm.expectRevert(MultiSig.MultiSig__NotEnoughAllowance.selector);
        multiSig.fundContract(address(mockToken), STARTING_BALANCE_OF_ADMINS);

        vm.stopPrank();
    }

    function testAttackerProposeWithdrawProposal(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        address attacker = makeAddr("attacker");
        vm.expectRevert(MultiSig.MultiSig__OnlyAdminAllowed.selector);
        vm.prank(attacker);
        multiSig.proposeWithdrawal(
            address(mockToken),
            attacker,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
    }

    function testRevertTokenNotAllowedWithdrawalProposal(
        uint256 _addressIndex
    ) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        vm.expectRevert(MultiSig.MultiSig__TokenIsNotAllowed.selector);
        vm.prank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
    }

    function testRevertNotEnoughBalance(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        vm.expectRevert(MultiSig.MultiSig__NotEnoughTokenBalance.selector);
        vm.prank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            STARTING_BALANCE_OF_ADMINS,
            "Funds need for charity donation"
        );
    }

    function testWithdrawalProposal(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        vm.prank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
        assertEq(multiSig.getIsThereActiveProposal(), true);
        assertEq(multiSig.getAllWithdrawalProposal().length, 1);
    }

    function testCorrectWithdrawalProposal(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        vm.prank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
        bytes32 currentWithdrawlProposalId = multiSig
            .getActiveWithdrawalProposal();
        bytes32 expectedProposal = keccak256(
            abi.encode(multiSig.getAllWithdrawalProposal()[0])
        );
        bytes32 result = keccak256(
            abi.encode(
                multiSig.getWithdrawalProposal(currentWithdrawlProposalId)
            )
        );
        assertEq(expectedProposal, result);
    }

    function testRevertOnDoubleProposal(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        vm.startPrank(sender);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Funds need for charity donation"
        );
        vm.expectRevert(MultiSig.MultiSig__ThereisActiveProposal.selector);
        multiSig.proposeWithdrawal(
            address(mockToken),
            CHARITY_RECEIVER,
            DEPOSIT_AMOUNT,
            "Need to go for shopping"
        );
        vm.stopPrank();
    }

    function testBalanceUpdateAfterDeposit(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        uint256 contractBalance = multiSig.getTokenBalanceInContract(
            address(mockToken)
        );
        assertEq(contractBalance, DEPOSIT_AMOUNT);
    }

    function testVotingNoActiveProposal(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        vm.expectRevert(MultiSig.MultiSig__NoActvieProposalCurrently.selector);
        vm.prank(sender);
        multiSig.voteOnWithdrawalProposal(keccak256(abi.encode("0x")), true);
    }

    function testAdminCanVote(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        proposeWithdrawal(sender);
        bytes32 proposalId = multiSig.getActiveWithdrawalProposal();
        uint256 dynamicVoter;
        if (index == 2) {
            dynamicVoter = index - 1;
        } else {
            dynamicVoter = index + 1;
        }
        vm.prank(adminsAddress[dynamicVoter]);
        multiSig.voteOnWithdrawalProposal(proposalId, true);

        bool voted = multiSig.getAddressAlreadyVoted(
            proposalId,
            adminsAddress[dynamicVoter]
        );
        MultiSig.WithdrawalProposal memory currentProposal = multiSig
            .getWithdrawalProposal(proposalId);

        assertEq(voted, true);
        assertEq(currentProposal.yesVote[0], adminsAddress[dynamicVoter]);
    }

    function testCannotVoteTwice(uint256 _addressIndex) public {
        uint256 index = bound(_addressIndex, 0, adminsAddress.length - 1);
        address sender = adminsAddress[index];
        tokenAdd(sender);
        depositToken(sender, DEPOSIT_AMOUNT);
        proposeWithdrawal(sender);
        bytes32 proposalId = multiSig.getActiveWithdrawalProposal();
        uint256 dynamicVoter;
        if (index == 2) {
            dynamicVoter = index - 1;
        } else {
            dynamicVoter = index + 1;
        }
        vm.startPrank(adminsAddress[dynamicVoter]);

        multiSig.voteOnWithdrawalProposal(proposalId, true);
        vm.expectRevert(MultiSig.MultiSig__AdressAlreadyVoted.selector);
        multiSig.voteOnWithdrawalProposal(proposalId, false);
        vm.stopPrank();
    }

    function testRevertOnNoneProposerResolve() public {
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.expectRevert(MultiSig.MultiSig__OnlyProposerAllowed.selector);
        vm.prank(adminsAddress[1]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
    }

    function testVotingTimeStillOpen() public {
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.expectRevert(MultiSig.MultiSig__ProposalWaitTimeNotOver.selector);
        vm.prank(adminsAddress[0]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
    }

    function testAllAdminsNotVoted() public {
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(MultiSig.MultiSig__AllAdminsNotVoted.selector);
        vm.prank(adminsAddress[0]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
    }

    function testYesVotePassed() public {
        uint256 startingBalance = ERC20Mock(mockToken).balanceOf(
            CHARITY_RECEIVER
        );
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.prank(adminsAddress[1]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, true);
        vm.prank(adminsAddress[2]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, true);
        vm.warp(block.timestamp + 3 days);
        vm.prank(adminsAddress[0]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
        uint256 expectedBalance = startingBalance + DEPOSIT_AMOUNT;
        uint256 resultBalance = ERC20Mock(mockToken).balanceOf(
            CHARITY_RECEIVER
        );
        MultiSig.WithdrawalProposal memory proposal = multiSig
            .getWithdrawalProposal(latestProposalId);
        bool activeProposal = multiSig.getIsThereActiveProposal();
        assertEq(expectedBalance, resultBalance);
        assertEq(multiSig.getTokenBalanceInContract(mockToken), 0);
        assertEq(proposal.isProposalPassed, true);
        assertEq(activeProposal, false);
    }

    function testNoVotePassed() public {
        uint256 startingBalance = ERC20Mock(mockToken).balanceOf(
            CHARITY_RECEIVER
        );
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.prank(adminsAddress[1]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, false);
        vm.prank(adminsAddress[2]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, false);
        vm.warp(block.timestamp + 3 days);
        vm.prank(adminsAddress[0]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
        assertEq(
            startingBalance,
            ERC20Mock(mockToken).balanceOf(CHARITY_RECEIVER)
        );
        assertEq(multiSig.getTokenBalanceInContract(mockToken), DEPOSIT_AMOUNT);
    }

    function testMixedVoting() public {
        uint256 startingBalance = ERC20Mock(mockToken).balanceOf(
            CHARITY_RECEIVER
        );
        tokenAdd(adminsAddress[0]);
        depositToken(adminsAddress[0], DEPOSIT_AMOUNT);
        proposeWithdrawal(adminsAddress[0]);
        bytes32 latestProposalId = multiSig.getActiveWithdrawalProposal();
        vm.prank(adminsAddress[1]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, true);
        vm.prank(adminsAddress[2]);
        multiSig.voteOnWithdrawalProposal(latestProposalId, false);
        vm.warp(block.timestamp + 3 days);
        vm.prank(adminsAddress[0]);
        multiSig.resolveWithdrawalProposal(latestProposalId);
        assertEq(
            startingBalance,
            ERC20Mock(mockToken).balanceOf(CHARITY_RECEIVER)
        );
        assertEq(multiSig.getTokenBalanceInContract(mockToken), DEPOSIT_AMOUNT);
    }
}
