// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IYKZNFT is IERC721 {
    function newLockNft (address to, uint8 tribe, uint8 season) external returns (uint256);
    function newUnLockNft (address to, uint8 tribe, uint8 season, bytes15 genes) external returns (uint256);
    function unLockNft (uint256 tokenId, bytes15 genes) external;
    function isLockNft (uint256 tokenId) external view returns(bool);
    function setNftName (uint256 tokenId, string calldata name) external;
    function setGenes (uint256 tokenId, bytes15 genes) external;
    function levelUp (uint256 tokenId, uint256 enchantYKZ, uint8 level) external returns(uint256);
    function getNftInfo(uint256 tokenId) external view
      returns (bool lock, uint8 tribe, uint8 season, bytes15 genes, uint256 enchantYKZ, string memory name, uint8 level);
    function getEnchantYKZ(uint256 tokenId) external view returns (uint256 enchantYKZ);
}