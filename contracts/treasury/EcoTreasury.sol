//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract EcoTreasury is Initializable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");        

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    event RoundRewardClaimComplete(uint256 claimId, bytes32 hash);
    event SeasonRewardClaimComplete(uint256 claimId, bytes32 hash);
    event RoundDistributed(uint256 indexed round, uint256 devfundFee, uint256 ltFee, uint256 freeBulletSupply);
    
    IERC20Upgradeable public _ykz;
    address public _signer;
    uint256 public _totalRoundClaim;
    mapping(uint256 => bool) private _usedRoundClaimIds;
    mapping(uint256 => bool) public _roundDistributed;

    uint256 public _totalSeasonClaim;
    mapping(uint256 => bool) private _usedSeasonClaimIds;

    function initialize(IERC20Upgradeable ykz, address signer) initializer public {
        __AccessControl_init();        
        __UUPSUpgradeable_init();   
        __ReentrancyGuard_init();

        _ykz = ykz;
        _signer = signer;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);        
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, signer);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function setSigner(address signer) external onlyRole(OPERATOR_ROLE) {
        require(address(0) != address(signer) && address(0xdead) != address(signer), "invalid address");        
        _signer = signer;
    }

    function roundDistribute(
        uint256 round,
        uint256 devfundFee,
        uint256 ltFee,
        uint256 freeBulletSupply,
        address devfund,
        address lockupTreasury,
        address communityTreasury
    ) external onlyRole(OPERATOR_ROLE) {      
        require(!_roundDistributed[round], "already distributed");        
        uint256 total = devfundFee.add(ltFee);
        require( _ykz.balanceOf(address(this)) >= total, "not enough ykz");
        require( _ykz.allowance(communityTreasury, address(this)) >= freeBulletSupply, "not enough community allowance");

        if( devfundFee > 0 ) {
            _ykz.safeTransfer(devfund, devfundFee);
        }

        if( ltFee > 0 ) {
            _ykz.safeTransfer(lockupTreasury, ltFee);
        }

        if( freeBulletSupply > 0 ) {
            _ykz.safeTransferFrom(msg.sender, address(this), freeBulletSupply);            
        }

        _roundDistributed[round] = true;
        emit RoundDistributed(round, devfundFee, ltFee, freeBulletSupply);        
    }    

    function claimRoundReward(
        bytes32 hash,
        bytes calldata signature,
        uint256 claimId,
        uint256 amount
    ) external nonReentrant {
        require(!_usedRoundClaimIds[claimId], "already claimed");
        require(hash == keccak256(abi.encode(msg.sender, claimId, amount)), "invalid hash");
        require(ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == _signer, "invalid signature");
        
        _ykz.safeTransfer(msg.sender, amount);
        _totalRoundClaim = _totalRoundClaim.add(amount);

        _usedRoundClaimIds[claimId] = true;
        emit RoundRewardClaimComplete(claimId, hash);
    }

    function claimSeasonReward(
        bytes32 hash,
        bytes calldata signature,
        uint256 claimId,
        address claimer,
        uint256 amount
    ) external nonReentrant {        
        require(!_usedSeasonClaimIds[claimId], "already claimed");
        require(hash == keccak256(abi.encode(msg.sender, claimId, claimer, amount)), "invalid hash");
        require(ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == _signer, "invalid signature");
        
         _ykz.safeTransfer(claimer, amount);
        _totalSeasonClaim = _totalSeasonClaim.add(amount);
        
        _usedSeasonClaimIds[claimId] = true;
        emit SeasonRewardClaimComplete(claimId, hash);
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
    function recoverToken(IERC20Upgradeable token) external onlyRole(OPERATOR_ROLE) {
        require(_ykz != token, "ykz is not recoverable.");
        uint256 balance = token.balanceOf(address(this));
        //solhint-disable-next-line reason-string
        require(balance != 0); // no error string to keep contract in size limits

        token.safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(token, balance);
    }
}
 