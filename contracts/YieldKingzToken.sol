// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract YieldKingzToken is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ERC20Permit, ERC20Votes {

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");    

    constructor() ERC20("YieldKingzToken", "YKZ") ERC20Permit("YieldKingzToken") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);        
    }

    function snapshot() public onlyRole(OPERATOR_ROLE) {
        _snapshot();
    }

    function pause() public onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    /**
     * @notice Allows the owner to recover non-fungible tokens sent to the contract by mistake
     * @param token: NFT token address
     * @param tokenId: tokenId
     * @dev Callable by owner
     */
    function recoverNonFungibleToken(IERC721 token, uint256 tokenId) external onlyRole(OPERATOR_ROLE) {
        token.approve(address(msg.sender), tokenId);
        token.safeTransferFrom(address(this), address(msg.sender), tokenId);

        emit NonFungibleTokenRecovery(token, tokenId);
    }

    /**
     * @notice Allows the owner to recover tokens sent to the contract by mistake
     * @param token: token address
     * @dev Callable by owner
     */
    function recoverToken(IERC20 token) external onlyRole(OPERATOR_ROLE) {
        uint256 balance = token.balanceOf(address(this));
        //solhint-disable-next-line reason-string
        require(balance != 0); // no error string to keep contract in size limits

        token.safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(token, balance);
    }
}