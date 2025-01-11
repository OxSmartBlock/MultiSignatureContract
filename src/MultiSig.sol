//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
@author OxSmartBlock
```
Details
This is Multisig contract that is supposed to accept tokens agree by the three admins that controls the contract. 
New proposal have 3days to pass. 
The proposer of adding new asset and withdrawal cannot vote to pass any proposal.
Passed proposal needs two of the three admins to vote yes.
Tie and higher No vote recorded as proposal not passed
``
**/

contract MultiSig {
    error MultiSig__TokenIsNotAllowed();
    error MultiSig__ThereisActiveProposal();
    error MultiSig__OnlyAdminAllowed();
    error MultiSig__NotEnoughTokenBalance();
    error MultiSig__ZeroAmountNotAllowed();
    error MultiSig__NotEnoughAllowance();
    error MultiSig__TokenTransferFailed();
    error MultiSig__InvalidAddress();
    error MultiSig__NoActvieProposalCurrently();
    error MultiSig__AdressAlreadyVoted();
    error MultiSig__ProposalAlreadyPassed();
    error MultiSig__AddressCannotVoteOnProposedProposal();
    //Event

    event NewWithdrawalProposal(
        address indexed proposer,
        address indexed contractAddress,
        uint256 amount
    );
    event VotedOnWithdrawalProposal(address indexed voter, bool _shouldPass);
    /**
     * @dev Custom Types
     */
    // How a wihdrawal proposer is structed
    struct WithdrawalProposal {
        address proposer; // address of admin that create new proposal
        address tokenContractAddress; // contract address of ERC20 token proposer is trying to withdraw
        address to; // receiver of the withdrawal if proposal passed
        address[] yesVote; // list of addresses that voted yes
        address[] noVote; // list of addresses that voted no
        uint256 amount; // amount the propser is trying to withdraw from the contract
        uint256 timeProposed; // when proposal is raised
        bytes32 proposalId; // unique id used for mapping all proposals
        bool isProposalPassed; // specified if proposal is already passed;
        string message; // Providing more context to the proposal
    }

    /**
     * @dev Storage Variables
     */
    address[3] private s_admins;
    address[] private s_allowedTokenContracts;
    WithdrawalProposal[] private s_allWithdrawalProposals;
    mapping(address tokenContract => bool ifAllowed) private s_isTokenAllowed;
    mapping(address => bool) private s_isAdmin;
    mapping(bytes32 => WithdrawalProposal) private s_idToProposal;
    // mapping(address => bool) private s_addressAlreadyVoted;
    mapping(address => uint256) s_tokenToAmount;
    mapping(bytes32 => mapping(address => bool)) s_addressAlreadyVoted;
    bool private s_isThereActiveProposal;
    bytes32 private s_activeWithdrwalProposal;
    uint256 constant PROPOSAL_WAIT_TIME = 3 days;

    /**
     *
     * @dev modifiers
     */

    /**
     *
     * @param _tokenContractAddress ERC20 token contract to be checked if allowed
     * @dev transaction revert if token is not allowed
     */
    modifier revertIfTokenNotAllowed(address _tokenContractAddress) {
        if (!s_isTokenAllowed[_tokenContractAddress]) {
            revert MultiSig__TokenIsNotAllowed();
        }
        _;
    }
    /**
     *
     * @dev modifier checks if there is an active proposal and revert to prevent double proposal
     */
    modifier revertIfThereIsActiveProposal() {
        if (s_isThereActiveProposal) {
            revert MultiSig__ThereisActiveProposal();
        }
        _;
    }

    modifier revertIfNotAdmin() {
        if (!s_isAdmin[msg.sender]) {
            revert MultiSig__OnlyAdminAllowed();
        }
        _;
    }

    modifier revertIfNotEnoughBalance(
        uint256 _amount,
        address _tokenContractAddress
    ) {
        if (IERC20(_tokenContractAddress).balanceOf(address(this)) < _amount) {
            revert MultiSig__NotEnoughTokenBalance();
        }
        _;
    }
    modifier revertOnZeroValueSent(uint256 _amount) {
        if (_amount == 0) {
            revert MultiSig__ZeroAmountNotAllowed();
        }
        _;
    }
    modifier revertIfNotEnoughAllowance(
        uint256 _amount,
        address _tokenContractAddress
    ) {
        if (
            _amount >
            IERC20(_tokenContractAddress).allowance(msg.sender, address(this))
        ) {
            revert MultiSig__NotEnoughAllowance();
        }
        _;
    }

    modifier revertOnZeroAddress(address _to) {
        if (_to == address(0)) {
            revert MultiSig__InvalidAddress();
        }
        _;
    }

    modifier revertOnNoActiveProposal() {
        if (!s_isThereActiveProposal) {
            revert MultiSig__NoActvieProposalCurrently();
        }
        _;
    }
    modifier revertOnAddressAlreadyVoted(bytes32 _proposalId) {
        if (s_addressAlreadyVoted[_proposalId][msg.sender]) {
            revert MultiSig__AdressAlreadyVoted();
        }
        _;
    }

    modifier revertOnProposalAlredyPassed(bytes32 _proposalId) {
        if (s_idToProposal[_proposalId].isProposalPassed) {
            revert MultiSig__ProposalAlreadyPassed();
        }
        _;
    }
    modifier revertOnProposerVoting(bytes32 _proposalId) {
        if (s_idToProposal[_proposalId].proposer == msg.sender) {
            revert MultiSig__AddressCannotVoteOnProposedProposal();
        }
        _;
    }

    /**
     *
     * @param _admins list of address allowed to sign transaction in the contract
     */

    constructor(address[3] memory _admins) {
        s_admins = _admins;
        for (uint i = 0; i < _admins.length; i++) {
            s_isAdmin[_admins[i]] = true;
        }
    }

    function fundContract(
        address _tokenContractAddress,
        uint256 _amount
    )
        external
        revertIfTokenNotAllowed(_tokenContractAddress)
        revertOnZeroValueSent(_amount)
        revertIfNotEnoughAllowance(_amount, _tokenContractAddress)
    {
        s_tokenToAmount[_tokenContractAddress] += _amount;
        bool isSuccessful = IERC20(_tokenContractAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!isSuccessful) {
            revert MultiSig__TokenTransferFailed();
        }
    }

    /**
     * External functions
     */

    function proposeWithdrawal(
        address _tokenContractAddress,
        address _to,
        uint256 _amount,
        string memory _message
    )
        external
        revertIfTokenNotAllowed(_tokenContractAddress)
        revertIfThereIsActiveProposal
        revertIfNotAdmin
        revertIfNotEnoughBalance(_amount, _tokenContractAddress)
        revertOnZeroAddress(_to)
    {
        bytes32 newProposalId = keccak256(
            abi.encodePacked(msg.sender, _tokenContractAddress, block.timestamp)
        );
        WithdrawalProposal memory newWithdrawalProposal = WithdrawalProposal({
            proposer: msg.sender,
            tokenContractAddress: _tokenContractAddress,
            to: _to,
            yesVote: new address[](0),
            noVote: new address[](0),
            amount: _amount,
            timeProposed: block.timestamp,
            proposalId: newProposalId,
            isProposalPassed: false,
            message: _message
        });
        s_activeWithdrwalProposal = newProposalId;
        s_isThereActiveProposal = true;
        s_idToProposal[newProposalId] = newWithdrawalProposal;
        s_allWithdrawalProposals.push(newWithdrawalProposal);
        emit NewWithdrawalProposal(msg.sender, _tokenContractAddress, _amount);
    }

    function voteOnWithdrawalProposal(
        bytes32 _proposalId,
        bool _shouldPass
    )
        external
        revertOnNoActiveProposal
        revertIfNotAdmin
        revertOnAddressAlreadyVoted(_proposalId)
        revertOnProposalAlredyPassed(_proposalId)
        revertOnProposerVoting(_proposalId)
    {
        if (_shouldPass) {
            s_idToProposal[_proposalId].yesVote.push(msg.sender);
        } else {
            s_idToProposal[_proposalId].noVote.push(msg.sender);
        }
        s_addressAlreadyVoted[_proposalId][msg.sender] = true;
        emit VotedOnWithdrawalProposal(msg.sender, _shouldPass);
    }

    function addNewAssetAllowed(
        address _contractAddress
    ) external revertIfNotAdmin {
        s_allowedTokenContracts.push(_contractAddress);
        s_isTokenAllowed[_contractAddress] = true;
    }

    /**
     * View functions
     */

    /**
     * @dev returns the address of admins that controls multi sig contract
     */

    function getAdmins() external view returns (address[3] memory) {
        return s_admins;
    }

    /**
     * @dev returns the list of addresses of ERC20 token address allowed by the multi contract
     */
    function getAllowedToken() external view returns (address[] memory) {
        return s_allowedTokenContracts;
    }

    /**
     *
     * @param _contractAddress Contract adress of an ERC20 token contract
     * @dev returns true if token is allowed false if token not allowed
     */

    function getIsTokenAllowed(
        address _contractAddress
    ) external view returns (bool) {
        return s_isTokenAllowed[_contractAddress];
    }

    function getIsThereActiveProposal() external view returns (bool) {
        return s_isThereActiveProposal;
    }

    function getWithdrawalProposal(
        bytes32 _proposalId
    ) external view returns (WithdrawalProposal memory) {
        return s_idToProposal[_proposalId];
    }

    function getAllWithdrawalProposal()
        external
        view
        returns (WithdrawalProposal[] memory)
    {
        return s_allWithdrawalProposals;
    }

    function getActiveWithdrawalProposal() external view returns (bytes32) {
        return s_activeWithdrwalProposal;
    }

    function getTokenBalanceInContract(
        address _tokenContractAddress
    ) external view returns (uint256) {
        return s_tokenToAmount[_tokenContractAddress];
    }

    function getAddressAlreadyVoted(
        bytes32 _proposalId,
        address _admin
    ) external view returns (bool) {
        return s_addressAlreadyVoted[_proposalId][_admin];
    }
}
