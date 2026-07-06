// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title WilToken (WhatIsLove)
 * @author Vladyslav (indigo04)
 * @notice This contract implements an upgradeable ERC-20 token.
 * @dev It uses the proxy architecture from OpenZeppelin. All initial setup
 * takes place in an initialization function instead of a constructor.
 */
contract WilToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    /**
     * @notice Constructor of the base implementation contract.
     * @dev Prevents the initialization of the base contract (implementation) for security reasons.
     * The state itself will be stored and configured in the proxy contract via the `initialize` function.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the token contract, setting the name, symbol, and initial owner.
     * @dev Replaces the standard constructor for compatibility with Upgradeable proxies.
     * Can be called only once during the entire lifecycle of the proxy.
     * @param initialOwner The address that will receive ownership rights to the contract (inherited from Ownable).
     */
    function initialize(address initialOwner) public initializer {
        __ERC20_init("WhatIsLove", "WIL");
        __Ownable_init(initialOwner);
    }

    /**
     * @notice Creates (mints) new tokens and sends them to the specified address.
     * @dev The token amount is specified taking the `decimals` into account (18 decimal places by default).
     * @param to Address of the new token recipient.
     * @param amount Number of tokens to create (in wei).
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
