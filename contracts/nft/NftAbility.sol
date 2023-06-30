// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract NftAbility is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    uint8 public constant MAX_NFT_LEVEL = 50;

    uint256[2][MAX_NFT_LEVEL] public _nftLevelTable;

    uint256 public _tokenPerHP;

    // 0 - Background, 1- Skin, 2-Hair, 3-Eyes, 4-Tatoo, 5 - Mouth, 6 - Muffler, 7 - Accesories

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _tokenPerHP = 100000000000000000; // 0.1
                              // accExp     accYKZ
        _nftLevelTable[ 0] = [0  ,   0e18];  // lv 1
        _nftLevelTable[ 1] = [248176  , 100e18]; // lv 2
        _nftLevelTable[ 2] = [634464  , 200e18];
        _nftLevelTable[ 3] = [1186640  , 300e18];
        _nftLevelTable[ 4] = [1936960  , 400e18];
        _nftLevelTable[ 5] = [2922828  , 500e18];
        _nftLevelTable[ 6] = [4334388  , 600e18];
        _nftLevelTable[ 7] = [6060672  , 700e18];
        _nftLevelTable[ 8] = [8154408  , 800e18]; // lv 9
        _nftLevelTable[ 9] = [10676172  , 900e18]; // lv 10
        _nftLevelTable[10] = [13695496  ,1000e18];
        _nftLevelTable[11] = [17709756  ,1100e18];
        _nftLevelTable[12] = [22470280  ,1200e18];
        _nftLevelTable[13] = [28093748  ,1300e18];
        _nftLevelTable[14] = [34713604  ,1400e18];
        _nftLevelTable[15] = [42482336  ,1500e18];
        _nftLevelTable[16] = [52629844  ,1600e18];
        _nftLevelTable[17] = [64851836  ,1700e18];
        _nftLevelTable[18] = [79485308  ,1800e18];
        _nftLevelTable[19] = [96916664  ,1900e18];
        _nftLevelTable[20] = [117588568  ,2000e18];
        _nftLevelTable[21] = [144843316  ,2100e18];
        _nftLevelTable[22] = [176927156  ,2200e18];
        _nftLevelTable[23] = [214579152  ,2300e18];
        _nftLevelTable[24] = [258643264  ,2400e18];
        _nftLevelTable[25] = [312532040  ,2500e18];
        _nftLevelTable[26] = [385481080  ,2600e18];
        _nftLevelTable[27] = [473343324  ,2700e18];
        _nftLevelTable[28] = [578541348  ,2800e18];
        _nftLevelTable[29] = [703852984  ,2900e18];
        _nftLevelTable[30] = [852460484  ,3000e18];
        _nftLevelTable[31] = [1048391140  ,3100e18];
        _nftLevelTable[32] = [1279037484  ,3200e18];
        _nftLevelTable[33] = [1549712564  ,3300e18];
        _nftLevelTable[34] = [1866483456  ,3400e18];
        _nftLevelTable[35] = [2253882508  ,3500e18];
        _nftLevelTable[36] = [2778303224  ,3600e18];
        _nftLevelTable[37] = [3409932924  ,3700e18];
        _nftLevelTable[38] = [4166187172  ,3800e18];
        _nftLevelTable[39] = [5067035444  ,3900e18];
        _nftLevelTable[40] = [6135354496  ,4000e18];
        _nftLevelTable[41] = [7543873264  ,4100e18];
        _nftLevelTable[42] = [9201958384  ,4200e18];
        _nftLevelTable[43] = [11147804616  ,4300e18];
        _nftLevelTable[44] = [13425027360  ,4400e18];
        _nftLevelTable[45] = [16083397264  ,4500e18];
        _nftLevelTable[46] = [19696303396  ,4600e18];
        _nftLevelTable[47] = [24062360892  ,4700e18];
        _nftLevelTable[48] = [29304804964  ,4800e18];
        _nftLevelTable[49] = [35565011184  ,4900e18];        
    }

    function getTokenPerHP() external view returns (uint256 tokenPerHP) {
        tokenPerHP = _tokenPerHP;
    }

    function getNeedExp(uint256 toLevel) external view returns(uint256 needExp) {
        needExp = _nftLevelTable[toLevel-1][0];
    }

    function getNeedYKZ(uint256 toLevel) external view returns(uint256 needYKZ) {
        needYKZ = _nftLevelTable[toLevel-1][1];
    }

    function setTokenPerHP(uint256 tokenPerHP) external onlyRole(OPERATOR_ROLE) {
        _tokenPerHP = tokenPerHP;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

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
    function recoverToken(IERC20Upgradeable token) external onlyRole(OPERATOR_ROLE) {
        uint256 balance = token.balanceOf(address(this));
        //solhint-disable-next-line reason-string
        require(balance != 0); // no error string to keep contract in size limits

        token.safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(token, balance);
    }
}