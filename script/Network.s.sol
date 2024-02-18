//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

/**
 * @dev This is the Network configuration script for the Lott contract
 * @notice all `console.log` statements are for debugging purposes and must be removed in the production version
 * @notice that `DEFAULT_SUB_ID` is kept 0, as the script will create one if it is not provided
 * @notice reduced the use of magic numbers.
 */

contract Network is Script {
    struct NetworkConfig {
        uint256 ticketPrice;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    /* State Variables */
    NetworkConfig public active_NetworkConfig;

    uint256 private constant GLOBAL_DRAW_INTERVAL = 0.3 minutes;
    uint256 private constant ETH_TICKET_PRICE = 0.01 ether;
    uint256 private constant ANVIL_TICKET_PRICE = 0.01 ether;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint64 private constant DEFAULT_SUB_ID = 0;
    uint64 private constant SEPOLIA_SUB_ID = 9396;
    uint32 private constant GLOBAL_CALLBACK_GAS_LIMIT = 500000;

    bytes32 private constant SEPOLIA_GASLANE = 
    0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    bytes32 private constant MAINNET_GASLANE =
    0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805;
    bytes32 private constant ANVIL_GASLANE = 
    0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    address private constant SEPOLIA_VRF = 
    0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    address private constant MAINNET_VRF =
    0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    address private constant SEPOLIA_LINK = 
    0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address private constant MAINNET_LINK =
    0x514910771AF9Ca656af840dff83E8264EcF986CA;

    /* Events */
    event Netwoer__createdMockVRFCoordinator(
        address indexed vrfCoordinator
    );

    /* Function */
    /* Constructor */
    /**
     * @dev The constructor sets the active network configuration based on the chain id
     * @notice The statement that sets main net configuration is commented out. It is only for testing purposes
     */
    constructor () {
        if (block.chainid == 11155111) {
            active_NetworkConfig = get_SepoliaEth_Config();
        }
        // else if (block.chainid == 1) {
        //      active_NetworkConfig = get_MainnetEth_Config();
        // }
        else {
            active_NetworkConfig = get_AnvilEth_Config();
        }
    }

    /* Public Functions */
    function get_MainnetEth_Config ()
        public
        view
        returns (NetworkConfig memory)
    {
        return NetworkConfig({
            ticketPrice: ETH_TICKET_PRICE,
            interval: GLOBAL_DRAW_INTERVAL,
            vrfCoordinator: MAINNET_VRF,
            gasLane: MAINNET_GASLANE,
            subscriptionId: DEFAULT_SUB_ID,
            callbackGasLimit: GLOBAL_CALLBACK_GAS_LIMIT,
            link: MAINNET_LINK,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
    function get_SepoliaEth_Config() 
        public 
        view 
        returns (NetworkConfig memory) 
    {
        return NetworkConfig({
            ticketPrice: ETH_TICKET_PRICE,
            interval: GLOBAL_DRAW_INTERVAL,
            vrfCoordinator: SEPOLIA_VRF,
            gasLane: SEPOLIA_GASLANE,
            subscriptionId: SEPOLIA_SUB_ID,
            callbackGasLimit: GLOBAL_CALLBACK_GAS_LIMIT,
            link: SEPOLIA_LINK,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function get_AnvilEth_Config() 
        public 
        returns (NetworkConfig memory) 
    {
        if(active_NetworkConfig.vrfCoordinator != address(0)) {
            return active_NetworkConfig;
        }

        uint96 _baseFee = 0.25 ether;
        uint96 _linkFee = 1e9;

        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            _baseFee, 
            _linkFee
        );

        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        emit Netwoer__createdMockVRFCoordinator(address(vrfCoordinator));

        return NetworkConfig({
            ticketPrice: ANVIL_TICKET_PRICE,
            interval: GLOBAL_DRAW_INTERVAL,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: ANVIL_GASLANE,
            subscriptionId: DEFAULT_SUB_ID,
            callbackGasLimit: GLOBAL_CALLBACK_GAS_LIMIT,
            link: address(linkToken),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}