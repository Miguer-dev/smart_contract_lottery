// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A Raffle Contract
 * @author Miguel Martinez
 * @notice This contract is for creating a raffle
 * @dev Implements Chainlink VRFv2 (VRFConsumerBaseV2) to get random number
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEntranceFee();
    error Raffle__FailCallWinner(bytes response);
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numUsers, State raffleState);

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
    event RequestRaffleWinner(uint256 indexed requestId);

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

    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's time to perform an upkeep.
     * The following should be true for this to return true:
     * 1. The tiem interval has passes between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscription is funded with LINK
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool isOpen = s_raffleState == State.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasUsers = s_users.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasUsers;
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle__UpkeepNotNeeded(address(this).balance, s_users.length, s_raffleState);

        s_raffleState = State.CLOSE;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATION, i_callbackGasLimit, NUM_WORDS
        );

        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, /*_requestId*/ uint256[] memory _randomWords) internal override {
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

    function getRaffleState() external view returns (State) {
        return s_raffleState;
    }

    function getUser(uint256 index) external view returns (address) {
        return s_users[index];
    }

    function getUserlenght() external view returns (uint256) {
        return s_users.length;
    }

    function getWinner() external view returns (address) {
        return s_winner;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }
}
