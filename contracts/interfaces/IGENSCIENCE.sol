// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

interface IGENSCIENCE {
    function createBasicNewGen(address sender, uint256 seed, bytes1 gender) external view returns (bytes15);
    function changeBasicNewGen(address sender, uint8 partsCount, uint256 seed, bytes15 oldGen) external view returns (bytes15, bool[10] memory);
}