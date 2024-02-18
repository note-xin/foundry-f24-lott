//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {Lott} from "src/Lott.sol";
import {Network} from "script/Network.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Subscribe} from "script/Interaction.s.sol";

/**
 * @title Tests the deployment aspect of the Lott contract
 * @notice note that the `console.log` statements are for debugging purposes comment them out
 */

contract LottStage is Test {
    /* State Variables */
    uint64 internal subscriptionId;
    uint32 internal callbackGasLimit;
    uint256 internal interval;
    uint256 internal ticketPrice;

    bytes32 internal gasLane;

    address internal vrfCoordinator;

    address public immutable i_player = vm.addr(3);
    uint256 public constant STARTING_BALANCE = 10 ether;

    Lott public lott;
    Network public network;

    /* Events */
    event LottStage__PurchacedTicket (
        address indexed _player
    );
    event LottStage__RequstedToPickWinner (
        uint256 indexed _requestId
    );
    event LottStage__PickedWinner (
        address indexed _winner
    );

    /* Modifiers */
    modifier pranked () {
        /* Arrange */
        vm.prank(i_player);

        _;
    }
    modifier funded () {
        /* Arrange */
        lott.purchaceTicket{
            value: ticketPrice
        }();

        _;
    }
    modifier passed () {
        /* Arrange */
        vm.warp(block.timestamp + interval+1);
        vm.roll(block.number + 1);

        _;
    }
    modifier local () {
        /* Arrange */
        if (block.chainid != 31337) {
            return;
        }

        _;
    }
    /* Functions */
    /* External Functions */
    function setUp () external {
        Deploy deploy = new Deploy();

        (lott, network) = deploy.run();
        vm.deal(i_player, STARTING_BALANCE);

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
    }
    /* Test Functions */
    /**@dev this test make sure `fulfillRandomWords()` can only be called after `performUpKeep()` is done 
     * @notice this test function is done localy
    */
    function test_verrifyFulfillRandomWordsCanOnlyBeCalledAfterPerformingUpkeep (uint256 randomRequestId) public 
        pranked 
        funded 
        passed 
        local {
        // Act
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lott)
        );

    }

     /**@dev this test the complte contract
     * @notice this test function is done localy
     */
    function test_verifyIfWholeContractWorks() public 
        pranked 
        funded 
        passed 
        local {
        // Arrange
        uint256 noOfPlayers = 10;
        uint256 index = 1;
        uint256 prize_money = noOfPlayers * ticketPrice;

        for (uint256 i = index; i < noOfPlayers; i++) {
            hoax(vm.addr(i), STARTING_BALANCE);
            lott.purchaceTicket{
                value: ticketPrice
            }();
        }

        uint256 lott_startingBalance = address(lott).balance;

        vm.recordLogs();
        lott.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = lott.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lott)
        );

        uint256 lott_endingBalance = address(lott).balance;

        // Assert
        assert(lott.getLottStatus() == Lott.LottStatus.Open);
        assert(lott.getNoOfPlayers() == 0);
        assert(lott_startingBalance == prize_money);
        assert(lott_endingBalance == 0);
        assert(lott.getRecentWinner() != address(0));
        assert(lott.getLastTimeStamp() > previousTimeStamp);
        assert(address(lott.getRecentWinner()).balance == (STARTING_BALANCE - ticketPrice) + prize_money);
    }

    /**@dev this makes sure that the subscription is made if there is none
     * @notice comment out the `console.log` statements as it is for debugging purposes
     * @notice this sets the subscription id to zero and cheks it after running the deployment script
     */
    function test_verifyThatSubcrptionIsMadeWhenSubIdIsZero() public {
        // Arrange
        lott.setSubscriptionId(0);
        uint64 startingSubscriptionId = lott.getSubscriptionId();
        console.log("---------------------------------------TEST-----------------------------------------");
        console.log("   Starting Subscription ID:",startingSubscriptionId);
        console.log("------------------------------------------------------------------------------------");

        Deploy deploy = new Deploy();
        (lott, network)  = deploy.run();

        uint64 newSubscriptionId = lott.getSubscriptionId();
        console.log("---------------------------------------TEST-----------------------------------------");
        console.log("   New test Subscription ID:",newSubscriptionId);
        console.log("------------------------------------------------------------------------------------");
        // Assert
        assert(startingSubscriptionId == 0);
        assert(newSubscriptionId != startingSubscriptionId);
    
    }
}