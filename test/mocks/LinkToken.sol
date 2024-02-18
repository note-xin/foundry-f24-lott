// SPDX-License-Identifier: MIT

/**
 * @title LinkToken
 * @author Patric Collins
 * @notice this contract is a reduced version of the LinkToken contract.
 */

// @dev This contract has been adapted to fit with Lott
pragma solidity ^0.8.18;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface ERC677Receiver {
    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes memory _data
    ) external;
}

contract LinkToken is ERC20 {
    // State variables
    uint256 constant INITIAL_SUPPLY = 10e26;
    uint8 constant DECIMALS = 18;

    // Events
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data
    );

    // Functions
    //// Constructor
    constructor() ERC20("LinkToken", "LINK", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    //// Public
    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contact.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public virtual returns (bool success) {
        super.transfer(_to, _value);
        // emit Transfer(msg.sender, _to, _value, _data);
        emit Transfer(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    //// PRIVATE
    function contractFallback(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private {
        ERC677Receiver receiver = ERC677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr) private view returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}