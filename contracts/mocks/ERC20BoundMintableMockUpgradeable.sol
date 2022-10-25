// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../token/ERC20/ERC20BoundMintableUpgradeable.sol";

contract ERC20BoundMintableMockUpgradeable is ERC20BoundMintableUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata name, string calldata symbol, uint256 defaultMinterCap) public initializer {
        __ERC20_init(name, symbol);
        __ERC20BoundMintableUpgradeable_init(defaultMinterCap);
    }

}
