// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVYKZ is IERC20 {
  function mintReward(address to, uint256 amount) external;
  function burn(uint256 amount) external;
}