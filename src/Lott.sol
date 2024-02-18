//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A sample Raffle Contract
 * @author note-xin
 * @notice this contract is a section of cyfrin-foundry-course-f23
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol"; 

contract Lott is VRFConsumerBaseV2, AutomationCompatibleInterface{
    /* Errors */
    /**@notice It is best practice to add contract name to the error name*/
    error Lott__LessThanTicketPrice();
    error Lott__IntervalNotPassed();
    error Lott__RequestIdDosntExists();
    error Lott__TransferFailed();
    error Lott__NotOpened();
    error Lott__CallculatingWinner();
    error Lott__NotEnoughPlayers();
    error Lott__UpkeepNotNeeded();

    /* Type Declarations */
    enum LottStatus {
        Open,
        Closed,
        CallculatingWinner
    }

    /* State Variables */ 
    uint16 private constant REQUEST_CONFRIMATIONS = 3;
    uint32 private constant NUM_WORDS =1;
    uint256 private constant MINIMUM_PLAYERS = 0;
    uint256 private constant ZERO_BALANCE = 0;

    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint64 private s_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    bytes32 private immutable i_gasLane;

    address payable[] private s_players;
    address private s_recentWinner;
    
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    LottStatus private s_lottStatus;
    
    /* Events */
    /**@notice It is best practice to add contract name to the event name*/
    event Lott__PurchacedTicket (
        address indexed _player
    );

    event Lott__PickedWinner (
        address indexed _winner
    );

    event Lott__RequestedToPickWinner (
        uint256 indexed _requestId
    );

    /* Functions */
    /* Constructor */
    constructor (
        uint256 ticketPrice,
        uint256 interval, 
        address vrfCoordinator,
        bytes32 gasLane, 
        uint64 subscriptionId,
        uint32 callbackGasLimit
        ) VRFConsumerBaseV2 (vrfCoordinator) {
        i_ticketPrice = ticketPrice;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_subscriptionId = subscriptionId;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_lottStatus = LottStatus.Open;
    }

    /* External Functions */ 
    /**
     * @dev This function allows players to purchace tickets
     * @notice This function is payable
     * @dev This function reverts if the lott is closed or winner is being callculated
     * @dev This function reverts if the value sent is less than the ticket price
     */
    function purchaceTicket () external payable {
        if (s_lottStatus == LottStatus.Closed) {
            revert Lott__NotOpened();
        }
        
        if (s_lottStatus == LottStatus.CallculatingWinner) {
            revert Lott__CallculatingWinner();
        }

        if (msg.value < i_ticketPrice) {
            revert Lott__LessThanTicketPrice();
        }

        s_players.push(payable(msg.sender));
        emit Lott__PurchacedTicket(msg.sender);
    }

    /**
     * @dev This is the function that is called by the Chainlink keeper nodes
     * @dev This function reverts if the interval has not passed or if there are not enough players
     * @param upkeepNeeded is a bool holds the value of whether the upkeep is needed or not
     */
    function checkUpkeep (
        bytes memory /* checkData */
        )   public 
            view 
            override 
            returns (bool upkeepNeeded, bytes memory) {
        bool passedInterval = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool enoughPlayers = s_players.length > MINIMUM_PLAYERS;
        bool enoughBalance = address(this).balance > ZERO_BALANCE; 
        bool isOpen = (s_lottStatus == LottStatus.Open);

        if (!enoughPlayers) {
            revert Lott__NotEnoughPlayers();
        }
        if (!passedInterval) {
            revert Lott__IntervalNotPassed();
        }
        upkeepNeeded = (passedInterval && enoughPlayers && enoughBalance && isOpen);
        
        return (upkeepNeeded, "");
    }

    /**
     * @dev This function checks `upkeepNeeded` and  if it is `false` it performs the upkeep
     * @notice the s_lottStatus is set to `CallculatingWinner` to prevent any further ticket purchaces when drawing the winner
     */
    function performUpkeep (bytes calldata /* performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lott__UpkeepNotNeeded();
        }

        s_lottStatus = LottStatus.CallculatingWinner;
        uint256 requestId = 
        i_vrfCoordinator.requestRandomWords (
            i_gasLane,
            s_subscriptionId,
            REQUEST_CONFRIMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        //s_lottStatus = LottStatus.Open;
        emit Lott__RequestedToPickWinner(requestId);
    }

    /* Internal Functions */
    /**
     * @dev This function is called by the performUpkeep function
     * @dev This exist to get the random words from the Chainlink VRF
     * here `index_winner` is the index of the winner which is calculated from the random words
     * @notice after the winner is picked the lott is opened again and the players array is reset
     */
    function fulfillRandomWords (
        uint256, 
        uint256[] memory randomWords
        ) internal override {
        uint256 index_winner = randomWords[0] % s_players.length;
        address payable winner = s_players[index_winner];

        s_recentWinner = winner;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        s_lottStatus = LottStatus.Open;

        emit Lott__PickedWinner(s_recentWinner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Lott__TransferFailed();
        }
    }

    /* Getter Functions */
    /**
     * @dev some of the getter functions are only used in the contract for testing purposes
     * @dev these functions are not used in the actual contract. so there to be commented.
     */
    function getTicketPrice() external view returns (uint256) {
        return i_ticketPrice;
    }

    function getLottStatus() external view returns (LottStatus) {
        return s_lottStatus;
    }

    function getNumWords() external pure returns (uint32) {
        return NUM_WORDS;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getNoOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getSubscriptionId() external view returns (uint64) {
        return s_subscriptionId;
    }

    /* Setter Functions */
    /**
     * @dev these setter functions are only used in the contract for testing purposes
     * @dev these functions are not to be used in the actual contract. so thery should be commented.
     */
    function setLottStatus(LottStatus status) external {
        s_lottStatus = status;
    }

    function setSubscriptionId(uint64 id) external {
        s_subscriptionId = id;
    }
}