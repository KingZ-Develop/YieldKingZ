// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

interface IABILITY {
    function getMaxAge(bytes15 gene) external pure returns (uint256 maxAge);
    function getTokenPerHP() external pure returns(uint256 tokenPerHP);
    function MAX_NFT_LEVEL() external pure returns(uint256);
    function getNeedExpAndYKZ(uint256 toLevel) external view returns(uint256 needExp, uint256 needYKZ);  
    function getNeedExp(uint256 toLevel) external view returns(uint256 needExp);
    function getNeedYKZ(uint256 toLevel) external view returns(uint256 needYKZ);
}
