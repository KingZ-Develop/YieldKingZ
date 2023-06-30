// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library Random {
  function randomSeed(address sender, uint256 seed) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(sender, block.timestamp, blockhash(block.number - 1), block.difficulty, seed)));
  }

  /// Random [0, modulus)
  function random(address sender, uint256 seed, uint256 modulus) internal view returns (uint256 nextSeed, uint256 result) {
    nextSeed = randomSeed(sender, seed);
    result = nextSeed % modulus;
  }

  /// Random [from, to)
  function randomRange(
    address sender,
    uint256 seed,
    uint256 from,
    uint256 to
  ) internal view returns (uint256 nextSeed, uint256 result) {
    require(from < to, "Invalid random range");
    (nextSeed, result) = random(sender, seed, to - from);
    result += from;
  }

  /// Random [from, to]
  function randomRangeInclusive(
    address sender,
    uint256 seed,
    uint256 from,
    uint256 to
  ) internal view returns (uint256 nextSeed, uint256 result) {
    return randomRange(sender, seed, from, to + 1);
  }
}