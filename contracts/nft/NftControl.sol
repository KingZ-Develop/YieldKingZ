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

import "../interfaces/IYKZNFT.sol";
import "../interfaces/IGENSCIENCE.sol";
import "../interfaces/IABILITY.sol";

contract NftControl is Initializable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");    

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);    

    event NewLockNFT(address indexed minter, uint256 newID, uint8 saleNum, uint8 tribe, uint256 price);
    event NewUnLockNFT(address indexed minter, uint256 newID, uint8 tribe, bytes15 genes, uint256 price);
    event UnLockNFT(uint256 indexed tokenId, bytes15 genes, address owner);
    event ChangeName(uint256 indexed tokenId, string name);
    event LevelUpNFT(uint256 indexed tokenId, uint256 addAmount, uint8 fromLevel, uint8 toLevel, uint256 enchantYKZ);
    event ChangeAppearance(uint256 indexed tokenId, bytes15 oldGenes, bytes15 newGenes, uint256 indexed itemIdx, bool[10] changeIndexs);

    event RepairHP(address indexed payer, uint256 indexed tokenId, uint256 recoverdHP, uint256 paymentAmount);

    struct SalesInfo {
        uint256 price;
        uint256 salesMax;
        CountersUpgradeable.Counter salesCount;
    }

    struct LevelUpFee {
        uint256 devFundPer;        
        uint256 tierPotPer;
        uint256 jackpotPer;
    }

    // Mapping from sales id to nft type 
    mapping(uint8 => mapping(uint8 => SalesInfo)) public _salesInfo;
    mapping(uint256 => bool) private _usedItemIdxs;

    IERC20Upgradeable public _ykz;
    IYKZNFT public _ykzNft;
    address public _lockupTreasury;
    address public _ecoTreasury;

    address payable public _devFund;
    IGENSCIENCE public _genscience;
    IABILITY public _ability;
    address public _signer;

    bool private _unLockAble;
    bool private _buyMintAble;

    uint8 public _maxMintingCount;
    uint256 public _mintPrice;

    LevelUpFee public _levelUpFee;

    function initialize(IERC20Upgradeable ykz, IYKZNFT ykzNft, address payable devFund, address lockupTreasury, address ecoTreasury, IGENSCIENCE genscience, IABILITY ability, address signer) initializer public {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _ykz = ykz;
        _ykzNft = ykzNft;
        _lockupTreasury = lockupTreasury;
        _ecoTreasury = ecoTreasury;
        _devFund = devFund;
        _genscience = genscience;
        _ability = ability;
        _signer = signer;

        _maxMintingCount = 5;
        _mintPrice = 1 ether;
        _levelUpFee.devFundPer = 1000;
        _levelUpFee.tierPotPer = 250;
        _levelUpFee.jackpotPer = 250;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, signer);
        _grantRole(UPGRADER_ROLE, msg.sender);
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

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function setYKZ(IERC20Upgradeable ykz) external onlyRole(OPERATOR_ROLE) {
        require(address(ykz) != address(0), "zero");
        _ykz = ykz;
    }

    function setYKZNFT(IYKZNFT ykzNft) external onlyRole(OPERATOR_ROLE) {
        require(address(ykzNft) != address(0), "zero");
        _ykzNft = ykzNft;
    }

    function setLockupTreasury(address lockupTreasury) external onlyRole(OPERATOR_ROLE) {        
        require(address(0) != lockupTreasury && address(0xdead) != lockupTreasury, "invalid address");
        _lockupTreasury = lockupTreasury;
    }

    function setEcoTreasury(address ecoTreasury) external onlyRole(OPERATOR_ROLE) {        
        require(address(0) != ecoTreasury && address(0xdead) != ecoTreasury, "invalid address");
        _ecoTreasury = ecoTreasury;
    }

    function setDevFund(address payable devFund) external onlyRole(OPERATOR_ROLE) {        
        require(address(0) != devFund && address(0xdead) != devFund, "invalid address");
        _devFund = devFund;
    }

    function setGeneScience(IGENSCIENCE genscience) external onlyRole(OPERATOR_ROLE) {        
        require(address(0) != address(genscience) && address(0xdead) != address(genscience), "invalid address");
        _genscience = genscience;
    }

    function setAbility(IABILITY ability) external onlyRole(OPERATOR_ROLE) {
        require(address(0) != address(ability) && address(0xdead) != address(ability), "invalid address");
        _ability = ability;
    }    

    function setSigner(address signer) external onlyRole(OPERATOR_ROLE) {
        require(address(0) != address(signer) && address(0xdead) != address(signer), "invalid address");        
        _signer = signer;
    }

    function setUnLockAble(bool unLockAble) external onlyRole(OPERATOR_ROLE) {        
        _unLockAble = unLockAble;
    }

    function getUnLockAble() external view returns(bool) {
        return _unLockAble;
    }

    function setBuyMintAble(bool buyMintAble) external onlyRole(OPERATOR_ROLE) {        
        _buyMintAble = buyMintAble;
    }

    function getBuyMintAble() external view returns(bool) {
        return _buyMintAble;
    }

    function setMaxMintingCount(uint8 maxMintingCount) external onlyRole(OPERATOR_ROLE) {
        require(maxMintingCount > 0, "invalid minting count");
        _maxMintingCount = maxMintingCount;
    }

    function setMintPrice(uint256 mintPrice) external onlyRole(OPERATOR_ROLE) {        
        require(mintPrice > 0, "invalid price");
        _mintPrice = mintPrice;
    }

    function setLevelUpFeeDevFundPer(uint256 percent) external onlyRole(OPERATOR_ROLE)
    {
        require(percent >= 0 && percent <= 10000, "out of range");
        _levelUpFee.devFundPer = percent;
    }

    function setLevelUpFeeTierPer(uint256 percent) external onlyRole(OPERATOR_ROLE)
    {
        require(percent >= 0 && percent <= 10000, "out of range");
        _levelUpFee.tierPotPer = percent;
    }

    function setLevelUpFeeJackpotPer(uint256 percent) external onlyRole(OPERATOR_ROLE)
    {
        require(percent >= 0 && percent <= 10000, "out of range");
        _levelUpFee.jackpotPer = percent;
    }        

    function addPresaleInfo(uint8 saleNum, uint8 tribe, uint256 price, uint256 max) external onlyRole(OPERATOR_ROLE) {        
        require(_salesInfo[saleNum][tribe].price == 0, "already info");

        _salesInfo[saleNum][tribe].price = price;
        _salesInfo[saleNum][tribe].salesMax = max;
    }

    function modPresaleInfo(uint8 saleNum, uint8 tribe, uint256 price, uint256 max) external onlyRole(OPERATOR_ROLE) {        
        require(_salesInfo[saleNum][tribe].price > 0, "not info");
        // require(_salesInfo[saleNum][tribe].salesCount.current() == 0, "already sale");

        _salesInfo[saleNum][tribe].price = price;
        _salesInfo[saleNum][tribe].salesMax = max;
    }

    // misteryPack By BNB
    function mintLockNft(uint8 saleNum, uint8 tribe, uint8 mintingCount) external payable whenNotPaused nonReentrant {
        require(mintingCount <= _maxMintingCount,"invalid minting count");
        require(msg.value > 0 && _salesInfo[saleNum][tribe].price.mul(mintingCount) == msg.value, "price error");
        require(_salesInfo[saleNum][tribe].salesCount.current().add(mintingCount) <= _salesInfo[saleNum][tribe].salesMax, "sold out");

        for( uint i=0; i < mintingCount; ++i ) {
            uint256 newID = _ykzNft.newLockNft(msg.sender, tribe, 1);
            _salesInfo[saleNum][tribe].salesCount.increment();

            emit NewLockNFT(msg.sender, newID, saleNum, tribe, _salesInfo[saleNum][tribe].price);
        }
    }

    function unLockNft(uint256 tokenId, uint256 seed) external whenNotPaused {
        require(_unLockAble, "Unlock impossible");
        require(_ykzNft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(_ykzNft.isLockNft(tokenId), "Already unlock");
        bytes15 genes = IGENSCIENCE(_genscience).createBasicNewGen(msg.sender, seed, 0x0);
        _ykzNft.unLockNft(tokenId, genes);

        emit UnLockNFT(tokenId, genes, msg.sender);
    }

    function mintUnLockNft(uint8 tribe, uint256 seed) external payable whenNotPaused nonReentrant {
        require(_buyMintAble, "buy impossible");       
        require(msg.value > 0 && _mintPrice == msg.value, "price error"); 

        bytes15 genes = IGENSCIENCE(_genscience).createBasicNewGen(msg.sender, seed, 0x0);
        uint256 newID = _ykzNft.newUnLockNft(msg.sender, tribe, 1, genes);        

        emit NewUnLockNFT(msg.sender, newID, tribe, genes, _mintPrice);
    }

    function getRemain(uint8 saleNum, uint8 tribe) external view returns (uint256) {
        return _salesInfo[saleNum][tribe].salesMax.sub(_salesInfo[saleNum][tribe].salesCount.current());
    }

    function setNftName(uint256 tokenId, string calldata name) external whenNotPaused {
        require(_ykzNft.ownerOf(tokenId) == msg.sender, "Not owner");
        require( bytes(name).length >= 4 && bytes(name).length < 16, "length check" );

        _ykzNft.setNftName(tokenId, name);
        emit ChangeName(tokenId, name);
    }

    function changeAppearance(
        bytes32 hash,
        bytes calldata signature,
        uint256 tokenId,
        uint256 itemIdx,
        uint8 partsCount,
        uint256 seed
    ) external whenNotPaused nonReentrant {
        require(!_usedItemIdxs[itemIdx], "already used");
        require(hash == keccak256(abi.encode(msg.sender, tokenId, itemIdx, partsCount)), "invalid hash");
        require(ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == _signer, "invalid signature");
        require(_ykzNft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(!_ykzNft.isLockNft(tokenId), "locked nft");

        (, , , bytes15 oldGenes, , ,) = _ykzNft.getNftInfo(tokenId);
        (bytes15 newGenes, bool[10] memory changeIndexs) = _genscience.changeBasicNewGen(msg.sender, partsCount, seed, oldGenes);

        _usedItemIdxs[itemIdx] = true;

        _ykzNft.unLockNft(tokenId, newGenes);

        emit ChangeAppearance(tokenId, oldGenes, newGenes, itemIdx, changeIndexs);
    }

    function changeAppearanceAdvanced(
        bytes32 hash,
        bytes calldata signature,
        uint256 tokenId,
        uint256 itemIdx,
        bytes15 newGenes,
        uint256 seed
    ) external whenNotPaused nonReentrant {
        require(!_usedItemIdxs[itemIdx], "already used");
        require(hash == keccak256(abi.encode(msg.sender, tokenId, itemIdx, newGenes)), "invalid hash");
        require(ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == _signer, "invalid signature");
        require(_ykzNft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(!_ykzNft.isLockNft(tokenId), "locked nft");

        _usedItemIdxs[itemIdx] = true;

        (, , , bytes15 oldGenes, , ,) = _ykzNft.getNftInfo(tokenId);
        _ykzNft.setGenes(tokenId, newGenes);

        bool[10] memory changeIndexs;

        emit ChangeAppearance(tokenId, oldGenes, newGenes, itemIdx, changeIndexs);
    }

    function levelupNFT(uint256 tokenId, uint8 addLevel, uint256 exp, uint256 addAmount) external whenNotPaused nonReentrant {
        require(_ykzNft.ownerOf(tokenId) == msg.sender, "Not owner");
        (, , , , uint256 currentYKZ, , uint8 fromLevel) = _ykzNft.getNftInfo(tokenId);
        uint8 toLevel = fromLevel + addLevel;
        require(exp >= _ability.getNeedExp(toLevel), "not enough exp");
        require(_ability.getNeedYKZ(toLevel).sub(currentYKZ) == addAmount, "invalid amount");
        require(toLevel > 1 && toLevel <= _ability.MAX_NFT_LEVEL(), "invalid level");

        uint256 enchantYKZ = _ykzNft.levelUp(tokenId, addAmount, toLevel);

        uint256 devFundFee = addAmount.mul(_levelUpFee.devFundPer).div(10000);
        uint256 tierFee = addAmount.mul(_levelUpFee.tierPotPer).div(10000);
        uint256 jackpotFee = addAmount.mul(_levelUpFee.jackpotPer).div(10000);

        uint256 lockupFee = addAmount.sub(devFundFee).sub(tierFee).sub(jackpotFee);

        _ykz.safeTransferFrom(msg.sender, _devFund, devFundFee);
        _ykz.safeTransferFrom(msg.sender, _ecoTreasury, tierFee.add(jackpotFee));
        _ykz.safeTransferFrom(msg.sender, _lockupTreasury, lockupFee);

        emit LevelUpNFT(tokenId, addAmount, fromLevel, toLevel, enchantYKZ);
    }

    function repairHP(uint256 tokenId, uint256 hp) external whenNotPaused nonReentrant {
        uint256 paymentAmount = _ability.getTokenPerHP().mul(hp);
        _ykz.safeTransferFrom(msg.sender, _ecoTreasury, paymentAmount);
        emit RepairHP(msg.sender, tokenId, hp, paymentAmount);
    }

    function withdrawBalance() external onlyRole(OPERATOR_ROLE) {
        uint256 amount = address(this).balance;
        require(amount > 0, "zero balance");
        payable(msg.sender).transfer(address(this).balance);
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
