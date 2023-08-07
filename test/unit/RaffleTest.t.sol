// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    DeployRaffle deployRaffle;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;

    address TEST_USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTTING_BALANCE = 10 ether;
    uint8 constant GAS_PRICE = 1;

    event EnteredRaffle(address indexed user);

    modifier raffleEnterAndTimePassed() {
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork (){
        if(block.chainid != 31337 || block.chainid != 5777){
            return;
        }
        _;
    }

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(TEST_USER, STARTTING_BALANCE);
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, linkToken,) =
            helperConfig.activeNetworkConfig();
    }

    function testInitialStateIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.State.OPEN);
    }

    //////////////////////////////
    ///       enterRaffle      ///
    //////////////////////////////

    function testNotEnoughEntranceFee() public {
        vm.prank(TEST_USER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRecordUserWhenEnter() public {
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getUser(0) == TEST_USER);
    }

    function testEmitEventOnEntrance() public {
        vm.prank(TEST_USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public raffleEnterAndTimePassed {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////
    ///       checkUpkeep      ///
    //////////////////////////////

    function testCheckUpkeepReturnFalseIfHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeede,) = raffle.checkUpkeep("");

        assert(!upkeepNeede);
    }

    function testCheckUpkeepReturnFalseIfRaffleNotOpen() public raffleEnterAndTimePassed {
        raffle.performUpkeep("");

        (bool upkeepNeede,) = raffle.checkUpkeep("");

        assert(!upkeepNeede);
    }

    function testCheckUpkeepReturnFalseIfEnoughtTimeHasntPassed() public {
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeede,) = raffle.checkUpkeep("");

        assert(!upkeepNeede);
    }

    function testCheckUpkeepReturnTrue() public raffleEnterAndTimePassed {
        (bool upkeepNeede,) = raffle.checkUpkeep("");

        assert(upkeepNeede);
    }

    //////////////////////////////
    ///     performUpkeep      ///
    //////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEnterAndTimePassed {
        //expect NotRevert not exist in foundry, only with this is okay, if the function revert the test fail.
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numUsers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numUsers, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitRequestId() public raffleEnterAndTimePassed {
        //record all event that trigger the next line
        vm.recordLogs();
        raffle.performUpkeep("");
        //Save all logs(events) in a Array type bytes32
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //You can get the position of the event you need with "forge test --debug <function>", topics[0] = entireEvent and topics[1] = firstParameter
        bytes32 requestId = entries[1].topics[1];

        Raffle.State rState = raffle.getRaffleState();

        assert(uint256(rState) == 1);
        assert(uint256(requestId) > 0);
    }

    //////////////////////////////
    ///   fulfillRandomWords   ///
    //////////////////////////////

    //Fuzz Test, Foundry generate randomRequestIds and run the test several times.
    function testFulfillRandomWordsCanOnlyBeCalledAdterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnterAndTimePassed skipFork
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnterAndTimePassed skipFork{
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        uint256 previousTimeStamp = raffle.getLastTimestamp();
        for (uint256 i = startingIndex; i <= additionalEntrants; i++) {
            address player = address(uint160(i)); //address(1), address(2) ...
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getWinner() != address(0));
        assert(raffle.getUserlenght() == 0);
        assert(raffle.getLastTimestamp() > previousTimeStamp); 
    }
}
