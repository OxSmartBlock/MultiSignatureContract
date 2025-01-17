//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 *@title MutiSig Contract
 @author OxSmartBlock
 @notice Multisig contract is a contract expected to be own and controlled by three admins.
 How it works
 -- Any of the admins is allowed to add ERC20 tokens address that should be allowed for deposit in the contract
 -- Incase of withdrawal an admin is expected to make a withdrawal proposal
 -- Withdrawal proposal are voted by the other two admins excluding the proposer of the withdrawal. 
 -- Withdrawal proposal is considered passed only if two admins vote yes to the proposal 
 -- Tie in voting is considered proposal not passed and also if the two admins voted no to the proposal

 */

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
    error MultiSig__OnlyProposerAllowed();
    error MultiSig__ProposalWaitTimeNotOver();
    error MultiSig__AllAdminsNotVoted();
    error MultiSig__CannotAddAlreadyAllowedToken();
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

    // Modifiers

    /**
     * @notice modifer check if token is allowed in the contract or not
     * @param _tokenContractAddress ERC20 token contract address that should be checked
     */
    modifier revertIfTokenNotAllowed(address _tokenContractAddress) {
        if (!s_isTokenAllowed[_tokenContractAddress]) {
            revert MultiSig__TokenIsNotAllowed();
        }
        _;
    }

    /**
     * @notice modifier checks if there is an active proposal waiting to be resloved. This prevent double proposal
     */
    modifier revertIfThereIsActiveProposal() {
        if (s_isThereActiveProposal) {
            revert MultiSig__ThereisActiveProposal();
        }
        _;
    }
    /**
     * @notice modifier restricts any user calling functions that should only be called by the admins alone
     */
    modifier revertIfNotAdmin() {
        if (!s_isAdmin[msg.sender]) {
            revert MultiSig__OnlyAdminAllowed();
        }
        _;
    }
    /**
     * @notice modifier checks if the contract have enough balance before a withdrawal proposal can be initiated
     */

    modifier revertIfNotEnoughBalance(
        uint256 _amount,
        address _tokenContractAddress
    ) {
        if (IERC20(_tokenContractAddress).balanceOf(address(this)) < _amount) {
            revert MultiSig__NotEnoughTokenBalance();
        }
        _;
    }
    /**
     * @notice modifier prevent zero value transactions from going through
     */
    modifier revertOnZeroValueSent(uint256 _amount) {
        if (_amount == 0) {
            revert MultiSig__ZeroAmountNotAllowed();
        }
        _;
    }
    /**
     * @notice modifier checks if user give enough token allowance for transfer to be successful
     */
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
    /**
     * @notice modifier checks if the receiver addres is not the zero address
     */
    modifier revertOnZeroAddress(address _to) {
        if (_to == address(0)) {
            revert MultiSig__InvalidAddress();
        }
        _;
    }
    /**
     * @notice modifer check if there is no active proposal prevent admins from voting when there is no proposal
     */

    modifier revertOnNoActiveProposal() {
        if (!s_isThereActiveProposal) {
            revert MultiSig__NoActvieProposalCurrently();
        }
        _;
    }

    /**
     * @notice modifier check if an address already voted to prevent double voting
     */
    modifier revertOnAddressAlreadyVoted(bytes32 _proposalId) {
        if (s_addressAlreadyVoted[_proposalId][msg.sender]) {
            revert MultiSig__AdressAlreadyVoted();
        }
        _;
    }
    /**
     * @notice modifer checks if a proposal have already been passed to prevent voting again
     */

    modifier revertOnProposalAlredyPassed(bytes32 _proposalId) {
        if (s_idToProposal[_proposalId].isProposalPassed) {
            revert MultiSig__ProposalAlreadyPassed();
        }
        _;
    }
    /**
     * @notice modifier prevent proposer from voting on their proposal
     */
    modifier revertOnProposerVoting(bytes32 _proposalId) {
        if (s_idToProposal[_proposalId].proposer == msg.sender) {
            revert MultiSig__AddressCannotVoteOnProposedProposal();
        }
        _;
    }
    /**
     * @notice modifer checks if the function call is the proposer
     */

    modifier revertIfNotProposer(bytes32 _proposalId) {
        if (msg.sender != s_idToProposal[_proposalId].proposer) {
            revert MultiSig__OnlyProposerAllowed();
        }
        _;
    }
    /**
     * @notice modifer prevent closing proposal when voting time is not over
     */
    modifier revertVotingTimeIsOpen(bytes32 _proposalId) {
        if (
            (block.timestamp - s_idToProposal[_proposalId].timeProposed) <
            PROPOSAL_WAIT_TIME
        ) {
            revert MultiSig__ProposalWaitTimeNotOver();
        }
        _;
    }
    /**
     * @notice modifier makes sure all admins voted before proposal is passed
     */

    modifier revertIfAllAdminNotVoted(bytes32 _proposalId) {
        WithdrawalProposal memory proposal = s_idToProposal[_proposalId];
        if ((proposal.yesVote.length + proposal.noVote.length) < 2) {
            revert MultiSig__AllAdminsNotVoted();
        }
        _;
    }
    modifier revertIfTokenIsAlreadyAllowed(address _tokenContract) {
        if (s_isTokenAllowed[_tokenContract]) {
            revert MultiSig__CannotAddAlreadyAllowedToken();
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

    //External functions

    /**
     * @param _tokenContractAddress Allowed ERC20 token contract address sender wish to deposit
     * @param  _amount Amount of token that should be trasnfered from sender to the contract
     * @dev transaction would revert if token is not allowed by the multisig contract
     * @dev transaction would revert if amount is zero
     * @dev trnsaction would revert if not enough allowance is gievn for the transfer
     * @notice call this function to make token deposit to the contract
     *
     */

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
     *@param _tokenContractAddress ERC20 token contract address the proposal need to withdraw
     @param _to the receiver address if the withdrawal proposal get passed
     @param _amount Amount the proposer is trying to withdraw from the contract 
     @param _message Context to the reason why the proposal should be accepted and voted to pass by other admins 
    @dev transaction would revert if token is not allowed by the multisig contract
    @dev transaction would revert if there is an active proposal waiting to be passed
    @dev transaction would revert if sender is an admin
    @dev transaction would revert if there is not enough balance to cover the withdrawal proposal
    @dev transaction woukd revert if the receiver address is zero address
    @notice call function to raise a new withdrawal proposal 
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
        // Hasing a new prosal id for uniqueness
        bytes32 newProposalId = keccak256(
            abi.encodePacked(msg.sender, _tokenContractAddress, block.timestamp)
        );
        // Making an instance of the withdrawal proposal type
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
        // updating the latest proposal id
        s_activeWithdrwalProposal = newProposalId;
        // make sure new proposal status is active
        s_isThereActiveProposal = true;
        // mapping proposal id to the proposal details
        s_idToProposal[newProposalId] = newWithdrawalProposal;
        // pushing the new proposal object to the list of proposal object
        s_allWithdrawalProposals.push(newWithdrawalProposal);
        // Loging to show a state have been updated
        emit NewWithdrawalProposal(msg.sender, _tokenContractAddress, _amount);
    }

    /**
     * @param _proposalId The uinqiue proposal id sender is willing to vote on
     * @param _shouldPass boolen value to indicate if a proposal should pass through or not
     * @notice true means yes to the proposal, false means no to the proposal
     * @dev transactiom would revert if there is no active proposal to be voted on
     * @dev transaction would revert if sender is not an admin
     * @dev transaction would revert if proposal have already been passed
     * @dev transacion would revert if the sender already voted
     * @dev transacton would revrt if the sender is the samething as the proposer
     * @notice call this function to vote on an active proposal
     */

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

    /**
     *
     * @param _proposalId proposal unique id sender wish to resolve
     * @dev transaction would revert if there is no active proposal
     * @dev transaction would revert if voting period is still open
     * @dev transaction woild revert if all admins have not voted
     * @dev transaction would revrt if propsal have already been passed
     * @notice call this function to resolve a pending proposal. Token would be sent if proposal is deemed accepted
     */

    function resolveWithdrawalProposal(
        bytes32 _proposalId
    )
        public
        revertIfNotProposer(_proposalId)
        revertVotingTimeIsOpen(_proposalId)
        revertIfAllAdminNotVoted(_proposalId)
        revertOnProposalAlredyPassed(_proposalId)
    {
        // Get the instance of the proposal using mapping of the id to proposal type
        WithdrawalProposal memory proposal = s_idToProposal[_proposalId];
        //updating proposal to  be recorded as passed
        s_idToProposal[_proposalId].isProposalPassed = true;
        // updating to show that there is not active proposal
        s_isThereActiveProposal = false;
        // Checking if the number of yes vote is larger than that of the number of no vote
        if (proposal.yesVote.length > proposal.noVote.length) {
            // Subtracting amount to be sent from the balance of token in contract
            s_tokenToAmount[proposal.tokenContractAddress] -= proposal.amount;
            // transfering token from contract to the receiving address
            bool isSuccess = IERC20(proposal.tokenContractAddress).transfer(
                proposal.to,
                proposal.amount
            );
            // checking if token transfer was successful or not
            if (!isSuccess) {
                revert MultiSig__TokenTransferFailed();
            }
        }
    }

    /**
     *
     * @param _contractAddress ERC20 token contract address to be added to list of accepted token in contract
     * @dev transaction would revert if sender is not a member of the admins
     * @dev transaction would revert if token is already allowed
     * @notice call this function to add new acceepted asset in the contract
     */

    function addNewAssetAllowed(
        address _contractAddress
    )
        external
        revertIfNotAdmin
        revertIfTokenIsAlreadyAllowed(_contractAddress)
    {
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

    /**
     *@notice call function to know if there is an active pending proposal
     */
    function getIsThereActiveProposal() external view returns (bool) {
        return s_isThereActiveProposal;
    }

    /**
     *  @param _proposalId the unique id use to identify each proposal proposed
     * @notice call this function to get the active state of a proposal
     */

    function getWithdrawalProposal(
        bytes32 _proposalId
    ) external view returns (WithdrawalProposal memory) {
        return s_idToProposal[_proposalId];
    }

    /**
     * @notice call this function to get list of all proposed withdrawal proposal
     * @dev this does not show the current state of the proposal
     */
    function getAllWithdrawalProposal()
        external
        view
        returns (WithdrawalProposal[] memory)
    {
        return s_allWithdrawalProposals;
    }

    /**
     * @notice call this function to get the proposal id of the active proposal
     */

    function getActiveWithdrawalProposal() external view returns (bytes32) {
        return s_activeWithdrwalProposal;
    }

    /**
     * @param _tokenContractAddress ERC20 token contract address
     * @notice call this function to get balance of an asset hold by the contract
     */
    function getTokenBalanceInContract(
        address _tokenContractAddress
    ) external view returns (uint256) {
        return s_tokenToAmount[_tokenContractAddress];
    }

    /**
     * @param _proposalId the unique id to identify a withdrawal proposal
     * @param _admin EOA address of member of the admins
     * @notice call this to know if an admin already voted on a proposal or not
     * @dev function call would return true if admin voted or not
     */

    function getAddressAlreadyVoted(
        bytes32 _proposalId,
        address _admin
    ) external view returns (bool) {
        return s_addressAlreadyVoted[_proposalId][_admin];
    }
}
