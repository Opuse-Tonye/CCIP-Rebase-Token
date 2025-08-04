// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";


/**
 * @title RebaseToken
 * @author Tonye
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */


contract RebaseToken is ERC20, Ownable, AccessControl {
    // ERRORS //

    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256 oldInterestRate, uint256 newInterestRate);

    // VARIABLES //
    uint256 private s_interestrate = (5 * PRECISION_FACTOR) / 1e8; // 10^-8 == 1/ 10^-8
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimeStamp;
    uint256 private constant PRECISION_FACTOR = 1e18;


    // EVENTS //
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner{
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
 * @notice Set the global interest rate for the contract.
 * @param _newInterestRate The new interest rate to set (scaled by PRECISION_FACTOR basis points per second).
 * @dev The interest rate can only decrease. Access control (e.g., onlyOwner) should be added.
 */

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set The Interest Rate
        if(_newInterestRate >= s_interestrate) {
            revert RebaseToken__InterestRateCanOnlyBeDecreased(s_interestrate, _newInterestRate);
        }
        s_interestrate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /** 
    * @notice Get the principle balance of a user. This is the number of tokens that have been minted to the user,
    not including any interest that has accrued since the last time the user interacted with the protocol.
    * @param _user Ther user to get the principle balance for
    * @return The principle balance of the user.
    */

    function principleBalanceOf(address _user) external view returns(uint256){
        return super.balanceOf(_user);
    }

    /**
 * @notice Mints tokens to a user, typically upon deposit.
 * @dev Also mints accrued interest and locks in the current global rate for the user.
 * @param _to The address to mint tokens to.
 * @param _amount The principal amount of tokens to mint.
 */

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestrate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
 * @notice Returns the current balance of an account, including accrued interest.
 * @param _user The address of the account.
 * @return The total balance including interest.
 */

    function balanceOf(address _user) public view override returns(uint256) {
        // get the current principle balanceOf the user (the number of tokens that have been minted to the user)
        // multiply the principle balance with the interest rate
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR; 
    }

    /**
 * @notice Transfers tokens from the caller to a recipient.
 * Accrued interest for both sender and recipient is minted before the transfer.
 * If the recipient is new, they inherit the sender's interest rate.
 * @param _recipient The address to transfer tokens to.
 * @param _amount The amount of tokens to transfer. Can be type(uint256).max to transfer full balance.
 * @return A boolean indicating whether the operation succeeded.
 */

    function transfer(address _recipient, uint256 _amount) public override returns(bool){
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool){
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf (_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
        // we need to calculate the last interest that has accumulated since last update
        // this is going to be linear growth with time 
        // (1) calculate the time since the last update
        // (2) calculate the amount of linear growth
        // Principal Amount (1 + (user Interest Rate * time elapsed))
        // deposit: 10 tokens
        // Interest rate 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 + (10 * 0.5 * 2) 
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    /**
 * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
 * @param _user The user to mint the accrued interest to
 */

    function _mintAccruedInterest(address _user) internal {
        // (1) Find there current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // (2) Calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // (3) Calculate the number of tokens that needs to be minted to the user. 2 -1
        uint256 balanceIncreased = (currentBalance - previousPrincipalBalance);
        // Call mint to mint tokens to the user.
        // set the user last updated timestamp.
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        _mint(_user, balanceIncreased);
    } 

    /**
 * @notice Get interest rate for the contract. Any future depositors will receive this interest rate
 * @return The interest rate for the contract
 */

    function getInterestRate() external view returns(uint256){
        return s_interestrate;
    }

    /**
 * @notice Gets the locked-in interest rate for a specific user.
 * @param _user The address of the user.
 * @return The user's specific interest rate.
 */

    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }
}