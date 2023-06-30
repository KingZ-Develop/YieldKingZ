// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/Random.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract NftGeneScience is Initializable, AccessControlUpgradeable, UUPSUpgradeable {    

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    uint8 private constant PARTS_COUNT = 10;
    uint256 private constant VARIATION_COUNT = 10;
    uint8 private constant MALE = 1;
    uint8 private constant FEMALE = 2;
    
    //@dev female parts rate (2000 - 20%, 100 - 1%)
    uint256 public _femaleRate;    

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {      
        __AccessControl_init();
        __UUPSUpgradeable_init();

        //@dev female parts rate (2000 - 20%, 100 - 1%)
        _femaleRate = 2000;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);        
        _grantRole(OPERATOR_ROLE, msg.sender);        
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function setFemaleRate(uint256 rate) external onlyRole(OPERATOR_ROLE) {
        require(rate >= 0 && rate <= 10000, "out of range");        
        _femaleRate = rate;
    }

    //@dev Basic method for creating new genes     
    function createBasicNewGen(address sender, uint256 seed, bytes1 gender)
    external
    view
    returns (bytes15)
    {
        bytes memory babyGen = new bytes(15);

        uint256 rand = 0;

        if( gender == 0x0 ) {
            (seed, rand) = Random.randomRangeInclusive(sender, seed, 1, 10000);
            // male, female
            if( rand < _femaleRate ) {
                babyGen[0] = bytes1(FEMALE);
            } else {
                babyGen[0] = bytes1(MALE);
            }
        } else {
            babyGen[0] = gender;
        }

        for (uint i = 1; i <= PARTS_COUNT; ++i) {
            (seed, rand) = Random.randomRangeInclusive(sender, seed, 1, VARIATION_COUNT);      
            babyGen[i] = bytes1(uint8(rand));
        }

        return _bytesToBytes15(babyGen);
    }

    //@dev Basic method for change new genes     
    function changeBasicNewGen(address sender, uint8 partsCount, uint256 seed, bytes15 oldGen)
    external
    view
    returns (bytes15, bool[PARTS_COUNT] memory)
    {
        bytes memory babyGen = new bytes(15);

        for (uint i = 0; i < 15; i++) {
            babyGen[i] = oldGen[i];
        }

        uint256 rand = 0;

        bool[PARTS_COUNT] memory shuffle;

        uint8 changeCount;
        if(partsCount == 0) {
            changeCount = PARTS_COUNT;
        } else {
            changeCount = partsCount;
        }

        for (uint8 i = 0; i < changeCount; ++i) {
            shuffle[i] = true;
        }

        for(uint256 j = 0; j < shuffle.length ; j++) {
            (seed, rand) = Random.randomRangeInclusive(sender, seed, 0, PARTS_COUNT-1);      
            bool currentValue = shuffle[j];
            bool valueToSwap = shuffle[rand];

            shuffle[j] = valueToSwap;
            shuffle[rand] = currentValue;
        }

        for (uint i = 1; i <= PARTS_COUNT; ++i) {
            if(shuffle[i-1]) {
                (seed, rand) = Random.randomRangeInclusive(sender, seed, 1, VARIATION_COUNT);      
                babyGen[i] = bytes1(uint8(rand));
            }
        }

        return (_bytesToBytes15(babyGen), shuffle);
    }

    //@dev Change Bytes to Byte15
    //@param b bytes
    function _bytesToBytes15(bytes memory _b)
    internal
    pure
    returns (bytes15)
    {
        bytes15 result;
        for (uint i = 0; i < 15; i++) {
            result |= bytes15(_b[i]) >> (i * 8);
        }
        return result;
    }        
}