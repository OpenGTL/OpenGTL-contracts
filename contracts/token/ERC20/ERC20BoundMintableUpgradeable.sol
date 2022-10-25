// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @dev ERC20 upgradeable token with support of bound minting
 * 
 * Accounts with `MINTER_ROLE` can mint no more than certain amount of tokens
 * which can be set both per-address and default.  
 */
abstract contract ERC20BoundMintableUpgradeable is AccessControlUpgradeable, ERC20Upgradeable {

    event MintingCapSet(address indexed newMinterAddress, uint256 mintingCap);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping (address => uint256) private _mintedAmounts;
    mapping (address => uint256) private _mintCapsPerAccount;

    uint256 private _defaultCap;

    /**
     * @dev Sets the value for {defaultCap}.
     * 
     * This value is immutable: once set during construction, it cannot be changed in future.
     */
    function __ERC20BoundMintableUpgradeable_init(uint256 defaultCap) internal onlyInitializing {
        __ERC20BoundMintableUpgradeable_init_unchained(defaultCap);
    }

    function __ERC20BoundMintableUpgradeable_init_unchained(uint256 defaultCap) internal onlyInitializing {
        require(defaultCap > 0, "ERC20BoundMintableUpgradeable: default cap should be positive");

        _defaultCap = defaultCap;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isMinter(address minter) public view returns (bool) {
        return hasRole(MINTER_ROLE, minter);
    }

    function mintingCap(address minter) public view returns (uint256) {
        require(isMinter(minter), "ERC20BoundMintableUpgradeable: Not a minter");
        return _mintCapsPerAccount[minter];
    }

    function amountOfMintedTokens(address minter) public view returns (uint256) {
        require(isMinter(minter), "ERC20BoundMintableUpgradeable: Not a minter");
        return _mintedAmounts[minter];
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Grant role MINTER_ROLE on given account. Can be called only by admin.
     * 
     * The minting cap of a new minter is {defaultCap}.
     */
    function addMinter(address newMinter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _addMinter(newMinter, _defaultCap);
    }

    /**
     * @dev Grant role MINTER_ROLE on given account with per-address minting cap. Can be called only by admin.
     */
    function addMinter(address newMinter, uint256 perAddressTokenCap) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _addMinter(newMinter, perAddressTokenCap);
    }

    /**
     * @dev Revoke MINTER_ROLE from given account. Can be called only by admin.
     * Reverts if account hasn't MINTER_ROLE.
     */
    function removeMinter(address minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isMinter(minter), "ERC20BoundMintableUpgradeable: Not a minter");

        _revokeRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Revoke MINTER_ROLE from caller. Reverts is caller is not a minter.
     */
    function renounceMinter() public onlyRole(MINTER_ROLE) {
        _revokeRole(MINTER_ROLE, _msgSender());
    }

    function _addMinter(address newMinter, uint256 mintCap) internal {
        require(!isMinter(newMinter), "ERC20BoundMintableUpgradeable: Already a minter");

        _mintedAmounts[newMinter] = 0;
        _mintCapsPerAccount[newMinter] = mintCap;

        _grantRole(MINTER_ROLE, newMinter);

        emit MintingCapSet(newMinter, mintCap);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from == address(0)) {    
            address minter = _msgSender();

            uint256 newAmount = _mintedAmounts[minter] + amount;
            require(newAmount <= _mintCapsPerAccount[minter], "ERC20BoundMintableUpgradeable: minting cap exceeded");
                
            _mintedAmounts[minter] = newAmount;
        } else {
            super._beforeTokenTransfer(from ,to, amount);
        }
    }

    uint256[46] private __gap;
}
