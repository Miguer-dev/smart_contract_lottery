// 4:19:21
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

pragma solidity >=0.8.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Raffle__NotEnoughEntranceFee();
error Raffle__FailCallWinner(bytes response);
error Raffle__NotOpen();

/**
 * @title A Raffle Contract
 * @author Miguel Martinez
 * @notice This contract is for creating a raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    enum State {
        OPEN,
        CLOSE
    }

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // Duration of the lottery in seconds
    address payable[] private s_users;
    address payable private s_winner;
    uint256 private s_lastTimestamp;
    State private s_raffleState;

    //Chain Link parameters for request a random number
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    event EnteredRaffle(address indexed user);
    event PickedWinner(address indexed user);

    constructor(
        uint256 entraceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entraceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimestamp = block.timestamp;
        s_winner = payable(address(0));
        s_raffleState = State.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEntranceFee();
        if (s_raffleState != State.OPEN) revert Raffle__NotOpen();

        s_users.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function _pickWinner() private {
        if ((block.timestamp - s_lastTimestamp) < i_interval) revert();
        s_raffleState = State.CLOSE;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATION, i_callbackGasLimit, NUM_WORDS
        );
    }

    //Design Pattern CEI: check, Effects, Interactions
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_users.length;
        s_winner = s_users[indexOfWinner];
        s_raffleState = State.OPEN;
        s_users = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        emit PickedWinner(s_winner);

        (bool success, bytes memory response) = s_winner.call{value: address(this).balance}("");
        if (!success) revert Raffle__FailCallWinner(response);
    }

    //Getter functions
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
