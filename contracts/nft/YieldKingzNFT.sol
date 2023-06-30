// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract YieldKingzNFT is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable, UUPSUpgradeable {    
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");      
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint8 public constant TRIBE_DOGS = 1;
    uint8 public constant TRIBE_CATS = 2;

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    struct NftInfo {       
        bool lock;
        uint8 tribe;
        uint8 season;
        bytes15 genes;
        uint256 enchantYKZ;
        string name;
        uint8 level;
        bool isFreeBulletDisable;
    }

    CountersUpgradeable.Counter private _tokenIdCounter;   
    string private _baseTokenURI;

    mapping(uint256 => NftInfo) private _nfts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("YieldKingz NFT", "YKZNFT");
        __ERC721Enumerable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _baseTokenURI = "https://localhost/";

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) external onlyRole(OPERATOR_ROLE) {
        _baseTokenURI = baseTokenURI;
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    function newLockNft (
        address to,
        uint8 tribe,
        uint8 season
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();        
        _safeMint(to, tokenId);

        NftInfo memory _nftInfo = NftInfo({            
            lock : true,
            tribe : tribe,
            season : season,
            genes : bytes15(0),
            enchantYKZ : 0,            
            name : "",
            level : 0,
            isFreeBulletDisable: false
        });
        _nfts[tokenId] = _nftInfo;

        return tokenId;
    }

    function newUnLockNft (
        address to,
        uint8 tribe,
        uint8 season,
        bytes15 genes
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();        
        _safeMint(to, tokenId);

        NftInfo memory _nftInfo = NftInfo({            
            lock : false,
            tribe : tribe,
            season : season,
            genes : genes,
            enchantYKZ : 0,
            name : "",
            level : 0,
            isFreeBulletDisable : false
        });
        _nfts[tokenId] = _nftInfo;

        return tokenId;
    }

    function unLockNft (
        uint256 tokenId,
        bytes15 genes        
    ) external onlyRole(MINTER_ROLE) whenNotPaused {  
        require(_nfts[tokenId].tribe > 0, "invalid token");
        _nfts[tokenId].lock = false;
        _nfts[tokenId].genes = genes;
        _nfts[tokenId].level = 1;
    }

    function isLockNft (uint256 tokenId) external view returns(bool) {    
        return _nfts[tokenId].lock;
    }

    function setNftName (
        uint256 tokenId,
        string calldata name
    ) external onlyRole(MINTER_ROLE) {
        require(_nfts[tokenId].tribe > 0, "invalid token");        
        _nfts[tokenId].name = name;
    }

    function setGenes (
        uint256 tokenId,
        bytes15 genes
    ) external onlyRole(MINTER_ROLE) {
        require(_nfts[tokenId].tribe > 0, "invalid token");        
        _nfts[tokenId].genes = genes;
    }

    function levelUp (
        uint256 tokenId,
        uint256 enchantYKZ,
        uint8 level
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(_nfts[tokenId].tribe > 0, "invalid token");
        _nfts[tokenId].enchantYKZ = _nfts[tokenId].enchantYKZ.add(enchantYKZ);
        _nfts[tokenId].level = level;
        return _nfts[tokenId].enchantYKZ;
    }

    function getNftInfo(uint256 tokenId) external view
      returns (bool lock, uint8 tribe, uint8 season, bytes15 genes, uint256 enchantYKZ, string memory name, uint8 level) {
        NftInfo memory nftInfo = _nfts[tokenId];
        lock = nftInfo.lock;
        tribe = nftInfo.tribe;
        season = nftInfo.season;        
        genes = nftInfo.genes;
        enchantYKZ = nftInfo.enchantYKZ;
        name = nftInfo.name;
        level = nftInfo.level;
    }

    function setEnchantYKZ(uint256 tokenId, uint256 enchantYKZ) external onlyRole(OPERATOR_ROLE) {
        _nfts[tokenId].enchantYKZ = enchantYKZ;
    }

    function getEnchantYKZ(uint256 tokenId) external view returns ( uint256 enchantYKZ) {
        return _nfts[tokenId].enchantYKZ;        
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
        uint256 balance = token.balanceOf(address(this));
        //solhint-disable-next-line reason-string
        require(balance != 0); // no error string to keep contract in size limits

        token.safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(token, balance);
    }    
}
