// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A Raffle Contract
 * @author Miguel Martinez
 * @notice This contract is for creating a raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entraceFee) {
        i_entranceFee = entraceFee;
    }

    function enterRaffle() external payable {}
    function pickWinner() private {}

    //Getter functions
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
