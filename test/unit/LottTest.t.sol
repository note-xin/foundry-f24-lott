//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {Lott} from "src/Lott.sol";
import {Network} from "script/Network.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

/**
 * @title Tests the functional aspects of the Lott contract
 * @notice note that the `console.log` statements are for debugging purposes comment them out
 * @dev All the tests are explained in theies respective names
 */

contract LottTest is Test {
    /* State variables */
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LESSTHAN_TICKET_PRICE = 0.001 ether;
    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant FIRST_MAN = 0;
    uint256 public ticketPrice;
    uint256 public interval;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit;
        
    address public immutable i_player = vm.addr(3);
    address public vrfCoordinator;
    address public link;

    bytes32 public gasLane;

    Lott public lott;
    Network public network;

    /* Events */
    event Lott__PurchacedTicket (
        address indexed _player
    );

    /* Modifiers */
    modifier closed () {
        // Arrange
        lott.setLottStatus(Lott.LottStatus.Closed);

        _;
    }
    modifier pranked () {
        // Arrange
        vm.prank(i_player);

        _;
    }
    modifier funded () {
        // Arrange
        lott.purchaceTicket{
            value: TICKET_PRICE
        }();

        _;
    }
    modifier passed () {
        // Arrange
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);

        _;
    }
    modifier performed () {
        // Arrange
        lott.performUpkeep("");

        _;
    }

    /* Functions */
    /* External Function */
    function setUp () external {
        Deploy deploy = new Deploy();
        (lott, network)  = deploy.run();
        (
            ticketPrice,
            interval, 
            vrfCoordinator,
            gasLane, 
            subscriptionId,
            callbackGasLimit,
            /*link*/,
            /*deployerKey*/ 

        ) = network.active_NetworkConfig();

        vm.deal(i_player, STARTING_BALANCE);
    }

    /* External Function */
    function test_verifyIfLottStateIsOpen() public view {
        // Assert
        assert(lott.getLottStatus() == Lott.LottStatus.Open);
    }

    function test_verifyIfTicketPriceIsCorrect() public view {
        // Assert
        assert(ticketPrice == TICKET_PRICE);
    }

    function test_verifyThatTicketCantBePurchasedWithLessMoney() public pranked {
        // Act
        vm.expectRevert(Lott.Lott__LessThanTicketPrice.selector);
        lott.purchaceTicket{
            value: LESSTHAN_TICKET_PRICE
        }();

    }

    function test_verifyIfPlayersAreRecorded() public pranked funded {
        // Arrange
        address player1 = lott.getPlayer(FIRST_MAN);

        // Assert
        assert(player1 == i_player);
    }

    function test_emitEventWhenTicketIsPurchased() public pranked {
        // Arrange
        vm.expectEmit(true, false, false, false);
        emit Lott__PurchacedTicket(i_player);

        // Act
        lott.purchaceTicket{
            value: TICKET_PRICE
        }();
    }

    function test_verifyCantEnterLottWhenItsClossed() public closed pranked {
        // Act
        vm.expectRevert(Lott.Lott__NotOpened.selector);
        lott.purchaceTicket{
            value: TICKET_PRICE
        }();
    }

    function test_verifyCantEnterLottWhenCalculatingWinner() public pranked funded passed performed {
        // Act
        vm.expectRevert(Lott.Lott__CallculatingWinner.selector);
        vm.prank(i_player);
        lott.purchaceTicket{
            value: TICKET_PRICE
        }();
    }

    function test_verifyUpkeepIsNotDoneWhenThereIsNoPlayers() public passed {
        // Act
        vm.expectRevert(Lott.Lott__NotEnoughPlayers.selector);
        lott.checkUpkeep("");
    }

    function test_veryfyIfUpkeepIsNotDoneWhenIntervalIsNotPassed() public pranked funded {
        // Act
        vm.expectRevert(Lott.Lott__IntervalNotPassed.selector);
        lott.checkUpkeep("");
    }

    function test_verifyIfUpkeepIsNotDoneWhenLotIsNotOpen() public pranked funded passed performed {
        // Act
        (bool upkeepNeeded, ) = lott.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function test_verifyIfUpkeepIsNotDoneWhenNotNeeded() public pranked funded passed performed {
        // Act
        vm.expectRevert(Lott.Lott__UpkeepNotNeeded.selector);
        lott.performUpkeep("");
    }

    function test_verifyIfUpkeepIsDoneWhenNeeded() public pranked funded passed {
        // Act
        (bool upkeepNeeded, ) = lott.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    function test_emitEventWhenRequstedToPickWinner() public pranked funded passed {
        // Act
        vm.recordLogs();
        lott.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lott.LottStatus lottStatus = lott.getLottStatus();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(lottStatus) == 2);
    }
}