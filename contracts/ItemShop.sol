//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract ItemShop is Initializable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCast for uint32;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    enum ItemType{ NONE, CONSUME, PERSIST }
    enum SaleStatus{ NONE, OFFSALE, ONSALE }

    struct Product {
      uint256 itemId;
      SaleStatus saleStatus;
      ItemType itemType;
      uint256 price;
    }
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");    

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    event ProductRegisted(uint256 productId);
    event ProductPurchased(uint256 indexed purchaseId, uint256 productId, address buyer, uint256 itemId, ItemType itemType, uint256 price, uint256 productCount);

    CountersUpgradeable.Counter public _purchaseIdIndex;

    mapping(uint256 => Product) public _products;

    address public _devFund;
    IERC20Upgradeable public _ykz;
    address public _ecoTreasury;
    address public _lockupTreasury;

    uint256 public _persistItemDevFeePer;
    uint256 public _maxBuyProductCount;

    uint256 public _persistItemTierPer;
    uint256 public _persistItemJackpotPer;

    function initialize(IERC20Upgradeable ykz, address devFund, address ecoTreasury, address lockupTreasury) initializer public {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        _devFund = devFund;        
        _ykz = ykz;        
        _ecoTreasury = ecoTreasury;
        _lockupTreasury = lockupTreasury;

        _persistItemDevFeePer = 1000;
        _persistItemTierPer = 250;
        _persistItemJackpotPer = 250;
        _maxBuyProductCount = 99;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
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

    function setDevFund(address devFund) external onlyRole(OPERATOR_ROLE) {
        require(address(devFund) != address(0), "zero");
        _devFund = devFund;
    }

    function setYKZ(IERC20Upgradeable ykz) external onlyRole(OPERATOR_ROLE) {
        require(address(ykz) != address(0), "zero");
        _ykz = ykz;
    }

    function setEcoTreasury(address ecoTreasury) external onlyRole(OPERATOR_ROLE) {
        require(address(ecoTreasury) != address(0), "zero");
        _ecoTreasury = ecoTreasury;
    }

    function setLockupTreasury(address lockupTreasury) external onlyRole(OPERATOR_ROLE) {
        require(address(lockupTreasury) != address(0), "zero");
        _lockupTreasury = lockupTreasury;
    }

    function setPersistItemDevFeePer(uint256 percent) external onlyRole(OPERATOR_ROLE) {
        require(percent >= 0 && percent <= 10000, "out of range");
        _persistItemDevFeePer = percent;
    }

    function setPersistItemTierPer(uint256 percent) external onlyRole(OPERATOR_ROLE) {
        require(percent >= 0 && percent <= 10000, "out of range");
        _persistItemTierPer = percent;
    }

    function setPersistItemJackpotPer(uint256 percent) external onlyRole(OPERATOR_ROLE) {
        require(percent >= 0 && percent <= 10000, "out of range");
        _persistItemJackpotPer = percent;
    }

    function setMaxBuyProductCount(uint256 maxBuyProductCount) external onlyRole(OPERATOR_ROLE) {
        require(maxBuyProductCount > 0, "zero");
        _maxBuyProductCount = maxBuyProductCount;
    }

    function setProduct(uint256 productId, uint256 itemId, SaleStatus saleStatus, ItemType itemType, uint256 price) external onlyRole(OPERATOR_ROLE) {
        require(productId > 0, "invalid productId");
        require(itemId > 0, "invalid itemId");
        require(saleStatus == SaleStatus.ONSALE || saleStatus == SaleStatus.OFFSALE, "invalid sale status");
        require(itemType == ItemType.PERSIST || itemType == ItemType.CONSUME, "invalid pay type");

        Product memory product = Product({
            itemId : itemId,
            saleStatus : saleStatus,
            itemType : itemType,
            price : price
        });
        _products[productId] = product;

        emit ProductRegisted(productId);
    }

    function buyProduct(uint256 productId, uint256 productCount) external whenNotPaused nonReentrant{
        require(productId > 0,"invalid productId");
        require(_products[productId].itemId > 0,"empty product");
        require(_products[productId].saleStatus == SaleStatus.ONSALE, "offsale product");
        require(productCount <= _maxBuyProductCount, "product count exceeds");

        uint256 buyPrice = _products[productId].price.mul(productCount);
        if(_products[productId].itemType == ItemType.PERSIST) {
            uint256 tierFee = buyPrice.mul(_persistItemTierPer).div(10000);
            uint256 jackpotFee = buyPrice.mul(_persistItemJackpotPer).div(10000);

            _ykz.safeTransferFrom(msg.sender, _devFund, buyPrice.mul(_persistItemDevFeePer).div(10000));
            _ykz.safeTransferFrom(msg.sender, _ecoTreasury, tierFee.add(jackpotFee));
            _ykz.safeTransferFrom(msg.sender, _lockupTreasury, buyPrice.mul(uint256(10000).sub(_persistItemDevFeePer).sub(_persistItemTierPer).sub(_persistItemJackpotPer)).div(10000));
        } else {
            _ykz.safeTransferFrom(msg.sender, _ecoTreasury, _products[productId].price.mul(productCount));
        }

        _purchaseIdIndex.increment();

        emit ProductPurchased(_purchaseIdIndex.current(), productId, msg.sender, _products[productId].itemId, _products[productId].itemType, _products[productId].price, productCount);
    }

    function isPersistItem(uint256 productId) external view returns(bool) {
        return _products[productId].itemType == ItemType.PERSIST;
    }

    function isConsumeItem(uint256 productId) external view returns(bool) {
        return _products[productId].itemType == ItemType.CONSUME;
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