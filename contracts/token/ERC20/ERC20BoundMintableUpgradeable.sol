// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title ERC20 upgradeable token with support of bound minting
 * @dev Accounts with `MINTER_ROLE` can mint no more than certain amount of tokens
 * @dev which can be set both per-address and default.  
 */
abstract contract ERC20BoundMintableUpgradeable is AccessControlUpgradeable, ERC20Upgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping (address => uint256) private _mintedAmounts;
    mapping (address => uint256) private _mintCapsPerAccount;

    uint256 private _defaultCap;

    function __ERC20BoundMintableUpgradeable_init(uint256 defaultCap) internal onlyInitializing {
        require(defaultCap > 0, "ERC20BoundMintableUpgradeable: default cap should be positive");

        _defaultCap = defaultCap;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function addMinter(address newMinter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _addMinter(newMinter, _defaultCap);
    }

    function addMinter(address newMinter, uint256 perAddressTokenCap) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _addMinter(newMinter, perAddressTokenCap);
    }

    function removeMinter(address minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "Not a minter");

        _revokeRole(MINTER_ROLE, minter);
    }

    function renounceMinter() public onlyRole(MINTER_ROLE) {
        _revokeRole(MINTER_ROLE, _msgSender());
    }

    function _addMinter(address newMinter, uint256 mintCap) internal {
        require(!hasRole(MINTER_ROLE, newMinter), "Already a minter");

        _mintedAmounts[newMinter] = 0;
        _mintCapsPerAccount[newMinter] = mintCap;

        _grantRole(MINTER_ROLE, newMinter);
    }

    uint256[46] private __gap;
}
