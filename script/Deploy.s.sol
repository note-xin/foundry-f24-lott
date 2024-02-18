//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Lott} from "src/Lott.sol";
import {Network} from "./Network.s.sol";
import {Subscribe, FundSubscription, AddConsumer} from "./Interaction.s.sol";

/**
 * @dev This is the deployment script for the Lott contract
 * @notice all `console.log` statements are for debugging purposes and must be removed in the production version
 */

contract Deploy is Script {
    function run () external returns (Lott, Network) {
        /* Before broadcasting */
        Network network = new Network();
        AddConsumer addConsumer = new AddConsumer();
        
        (
        uint256 ticketPrice,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link,
        uint256 deployerKey
        ) = network.active_NetworkConfig();

        if (subscriptionId == 0) {
            Subscribe subscribe = new Subscribe();
            (subscriptionId, vrfCoordinator) = subscribe.subscribeThis(
                vrfCoordinator, 
                deployerKey
            );
            console.log("-------------------------------NEW-SUB---------------------------------------------");
            console.log("   New Subscription created with ID:",subscriptionId);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionThis(vrfCoordinator, subscriptionId, link, deployerKey);
            console.log("   New Subscription funded with LINK");
            console.log("------------------------------------------------------------------------------------");
        }

        /* Broadcasting */
        vm.startBroadcast();
        Lott lott = new Lott
        (
            ticketPrice,
            interval, 
            vrfCoordinator,
            gasLane, 
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        // After broadcasting
        addConsumer.addConsumerThis(
            address(lott), 
            subscriptionId, 
            vrfCoordinator, 
            deployerKey
        );
        
        return (lott, network);
    }
}