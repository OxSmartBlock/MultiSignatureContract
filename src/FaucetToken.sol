//SPDX-License-Identifier:MIT

pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FaucetToken is ERC20 {
    error FaucetToken__WaitTimeNotOver();

    mapping(address => uint256) s_lastTimeMinted;
    mapping(address => bool) s_firstTime;
    uint256 constant MINIMUM_TIME_WAIT = 1 days;
    uint256 public constant DRIP_AMOUNT = 100 ether;

    constructor() ERC20("Charty Token", "CHR") {}

    function mint(address _to) external {
        if (s_firstTime[msg.sender] == false) {
            s_firstTime[msg.sender] = true;
            s_lastTimeMinted[msg.sender] = block.timestamp;
            _mint(_to, DRIP_AMOUNT);
        } else {
            _revertMintWaitTimeNotReached(msg.sender);
            s_lastTimeMinted[msg.sender] = block.timestamp;
            _mint(_to, DRIP_AMOUNT);
        }
    }

    function _revertMintWaitTimeNotReached(address _from) private view {
        if ((block.timestamp - s_lastTimeMinted[_from]) < MINIMUM_TIME_WAIT) {
            revert FaucetToken__WaitTimeNotOver();
        }
    }
}
