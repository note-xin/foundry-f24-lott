//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Network} from "./Network.s.sol";
import {Lott} from "src/Lott.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

/**
 * @dev This is the interaction script for the Lott contract
 * @notice all `console.log` statements are for debugging purposes and must be removed in the production version 
 */

contract Subscribe is Script {
    /* Functions */
    /* External Functions */
    function run() external returns (uint64, address) {
        return subscribeUsingConfig();
    }

    /* Public Functions */
    function subscribeUsingConfig() public returns (uint64, address) {
        Network network = new Network();
        (   ,
            , 
            address vrfCoordinator, 
            , 
            , 
            , 
            , 
            uint256 deployerKey
        ) = network.active_NetworkConfig();

        return subscribeThis(vrfCoordinator, deployerKey);
    }

    function subscribeThis(
        address vrfCoordinator, 
        uint256 deployerKey
    ) public returns (uint64, address) {
        console.log("------------------------------------------------------------------------------------");
        console.log("    Creating subscription on ChainID : ",block.chainid);

        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("    Subscription created with ID : ",subId);
        console.log("------------------------------------------------------------------------------------");

        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script {
    /* State variables */
    uint96 public constant FUND_AMOUNT = 3 ether;

    /* Functions */
    /* External Functions */
    function run() external {
        fundSubscriptionUsingConfig();
    }

    /* Public Functions */
    function fundSubscriptionUsingConfig() public {
        Network network = new Network();
        (
            , 
            , 
            address vrfCoordinator, 
            , 
            uint64 subId, 
            , 
            address link, 
            uint256 deployerKey
        ) = network.active_NetworkConfig();

        if (subId == 0) {
            Subscribe subscribe = new Subscribe();

            (uint64 updatedSubId, address updatedVRF) = subscribe.run();
            subId = updatedSubId;
            vrfCoordinator = updatedVRF;

            console.log("-------------------------------NEW-SUB---------------------------------------------");
            console.log("   New Subscription created with ID:",subId);
            console.log("   New Subscription created with VRF:",vrfCoordinator);
            console.log("------------------------------------------------------------------------------------");
        }

        fundSubscriptionThis(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscriptionThis(
        address vrfCoordinator, 
        uint64 subId, 
        address link, 
        uint256 deployerKey
    ) public {
        console.log("------------------------------------------------------------------------------------");
        console.log("    Funding subscription on subId : ",subId);
        console.log("    Using VRFCoordinator : ",vrfCoordinator);
        console.log("    On ChainID : ",block.chainid);
        console.log("    With LINK : ",link);

        if (block.chainid == 31337) {

            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        }
        else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log("------------------------------------------------------------------------------------");
    }
}

contract AddConsumer is Script {
    /* State variables */

    /* Functions */
    /* External Functions */
    function run() external {
        address recentLott = DevOpsTools.get_most_recent_deployment(
            "Lott", 
            block.chainid
        );
        
        addConsumerUsingConfig(recentLott);
    }

    /* Public Functions */
    function addConsumerUsingConfig (address recentLott) public {
        Network network = new Network();
        (
            , 
            , 
            address vrfCoordinator, 
            , 
            uint64 subId, 
            , 
            , 
            uint256 deployerKey
        ) = network.active_NetworkConfig();

        addConsumerThis(recentLott, subId, vrfCoordinator, deployerKey);

    }

    function addConsumerThis (
        address lottToAddToVRF, 
        uint64 subId, 
        address vrfCoordinator, 
        uint256 deployerKey
    ) public {
        console.log("------------------------------------------------------------------------------------");
        console.log("   Adding consumer on contract : ",lottToAddToVRF);
        console.log("   Using VRFCoordinator : ",vrfCoordinator);
        console.log("   On ChainID : ",block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId, 
            lottToAddToVRF
        );
        vm.stopBroadcast();
        console.log("------------------------------------------------------------------------------------");
    }
}