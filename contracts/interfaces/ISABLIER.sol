// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

interface ISABLIER {    
  function getStream(uint256 streamId)
        external
        view        
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        );
  function balanceOf(uint256 streamId, address who) external view returns (uint256 balance);
  function createStream(address recipient, uint256 deposit, address tokenAddress, uint256 startTime, uint256 stopTime) external returns (uint256);
  function cancelStream(uint256 streamId) external returns (bool);
  function withdrawFromStream(uint256 streamId, uint256 amount) external returns (bool);
}
