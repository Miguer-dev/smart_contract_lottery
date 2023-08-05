// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(TEST_USER, STARTTING_BALANCE);
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, linkToken) =
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
        raffle.enterRaffle{value: 0.001 ether}();
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

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval * 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(TEST_USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////
    ///       checkUpkeep      ///
    //////////////////////////////
}
