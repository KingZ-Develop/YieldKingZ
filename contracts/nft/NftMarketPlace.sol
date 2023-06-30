// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../interfaces/IYKZNFT.sol";

contract NftMarketPlace is Initializable, ERC721HolderUpgradeable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event NonFungibleTokenRecovery(IERC721 indexed token, uint256 tokenId);
    event TokenRecovery(IERC20Upgradeable indexed token, uint256 amount);

    event SaleCreated(uint256 indexed saleId, SaleType saleType, uint256 indexed tokenId, address seller, uint256 price);
    event SaleSuccessful(uint256 indexed saleId, SaleType saleType, uint256 indexed tokenId, address seller, address buyer, uint256 price, uint256 tradingFee);
    event SaleCanceled(uint256 indexed saleId, SaleType saleType, uint256 indexed tokenId, address seller);    
    event RentalSuccessful(uint256 indexed rentalId, uint256 saleId, uint256 indexed tokenId, address lender, address borrower, uint256 period, uint256 endingTime);
    event RetrieveRental(uint256 indexed rentalId, uint256 indexed tokenId, address lender, address borrower);
    event DevFundAddToken(FeeType feeType, uint256 timestamp, address sender, uint256 ykzAmount);

    CountersUpgradeable.Counter public totalSaleCount;
    CountersUpgradeable.Counter public totalRentalCount;
    CountersUpgradeable.Counter public saleIdIndex;
    CountersUpgradeable.Counter public rentalIdIndex;

    enum SaleType{ Sale, Rental } // 0 , 1
    enum FeeType{ SaleTrading, RentalTrading }

    struct SaleItem {
        uint256 id;
        SaleType saleType;
        address seller;
        uint256 price;
        uint256 tradingFeeAmount;
        uint256 maxRentalPeriod;
    }

    struct Rental {
        uint256 id;
        address lender;
        address borrower;
        uint256 rentalPrice;
        uint256 rentalPeriod;
        uint256 endingTime;
    }

    mapping(uint256 => SaleItem) public _tokenIdToSaleItem;
    mapping(uint256 => Rental) public _tokenIdToRental;

    mapping(address => EnumerableSet.UintSet) private _tokenOfSeller;
    mapping(address => EnumerableSet.UintSet) private _tokenOfLender;
    mapping(address => EnumerableSet.UintSet) private _tokenOfBorrower;

    // core components
    IERC20Upgradeable public _ykz;
    IYKZNFT public _ykzNft;
    address public _devFund;
    
    // parameters    
    uint256 public _registrationFeeAmount;
    uint256 public _saleFeePer;
    uint256 public _rentalFeePer;
    uint256 public _maxRentalPeriod;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IERC20Upgradeable ykz, IYKZNFT ykzNft, address devFund) initializer public {    
        __ERC721Holder_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _ykz = ykz;
        _ykzNft = ykzNft;
        _devFund = devFund;

        _registrationFeeAmount = 0;
        _saleFeePer = 1000;
        _rentalFeePer = 1000;
        _maxRentalPeriod = 30;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}    

    modifier onlyHolder(uint256 tokenId) {
        require(_ykzNft.ownerOf(tokenId) == msg.sender);
        _;
    }

    modifier onlySeller(uint256 tokenId) {
        require(_tokenIdToSaleItem[tokenId].seller == msg.sender, "not a seller");
        _;
    }

    modifier onlySellerOrOperator(uint256 tokenId) {
        require(_tokenIdToSaleItem[tokenId].seller == msg.sender || hasRole(OPERATOR_ROLE,msg.sender), "not a seller");
        _;
    }

    modifier onlyLender(uint256 tokenId) {
        require(_tokenIdToRental[tokenId].lender == msg.sender, "not a lender");
        _;
    }

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

    function setYKZNft(IYKZNFT ykzNft) external onlyRole(OPERATOR_ROLE) {
        require(address(ykzNft) != address(0), "zero");
        _ykzNft = ykzNft;
    }

    function setDevFund(address devFund) external onlyRole(OPERATOR_ROLE) {
        require(address(devFund) != address(0), "zero");
        _devFund = devFund;
    }

    function setRegistrationFeeAmount(uint256 registrationFeeAmount) external onlyRole(OPERATOR_ROLE) {
        _registrationFeeAmount = registrationFeeAmount;
    }

    function setSaleFeePer(uint256 saleFeePer) external onlyRole(OPERATOR_ROLE) {
        require(saleFeePer >= 0 && saleFeePer <= 10000, "out of range");  // [0% ~ 100%]
        _saleFeePer = saleFeePer;
    }

    function setRentalFeePer(uint256 rentalFeePer) external onlyRole(OPERATOR_ROLE) {
        require(rentalFeePer >= 0 && rentalFeePer <= 10000, "out of range");  // [0% ~ 100%]
        _rentalFeePer = rentalFeePer;
    }    

    function setMaxRentalPeriod(uint256 maxRentalPeriod) external onlyRole(OPERATOR_ROLE) {
        _maxRentalPeriod = maxRentalPeriod;
    }

    // emergency
    function withdrawAdmin(uint256 tokenId) external onlyRole(OPERATOR_ROLE) {
        _withdraw(tokenId);
    }

    function createSaleItem(
        SaleType saleType,
        uint256 tokenId,
        uint256 price,
        uint256 maxRentalPeriod
    ) whenNotPaused onlyHolder(tokenId) external returns(uint256) {
        require(price > 0, "zero salePrice");
        require(!_isOnSale(price), "on sale");
        _deposit(tokenId);

        uint256 tradingFeeAmount = 0;
        if( saleType == SaleType.Sale ) {
            if( _saleFeePer > 0 ) {
                tradingFeeAmount = price.mul(_saleFeePer).div(10000);
            }
            saleIdIndex.increment();
            SaleItem memory saleItem = SaleItem({
                id : saleIdIndex.current(),
                saleType : saleType,
                seller : msg.sender,
                price : price,
                tradingFeeAmount : tradingFeeAmount,
                maxRentalPeriod : 0
            });
            _tokenIdToSaleItem[tokenId] = saleItem;            
        } else {
            require(!_ykzNft.isLockNft(tokenId), "locked nft");
            require(maxRentalPeriod <= _maxRentalPeriod, "_maxRentalPeriod exceeded");
            if( _rentalFeePer > 0 ) {
                tradingFeeAmount = price.mul(_rentalFeePer).div(10000);
            }
            saleIdIndex.increment();
            SaleItem memory saleItem = SaleItem({
                id : saleIdIndex.current(),
                saleType : saleType,
                seller : msg.sender,
                price : price,
                tradingFeeAmount : tradingFeeAmount,
                maxRentalPeriod : maxRentalPeriod
            });
            _tokenIdToSaleItem[tokenId] = saleItem;            
        }

        totalSaleCount.increment();

        emit SaleCreated(_tokenIdToSaleItem[tokenId].id, saleType, tokenId, msg.sender, price);

        return tokenId;
    }

    function buySaleItem(uint256 tokenId, uint256 ykzAmount) whenNotPaused nonReentrant external {
        require(_isOnSale(tokenId), "no sale");
        require(msg.sender != _tokenIdToSaleItem[tokenId].seller, "you are seller");
        require(_tokenIdToSaleItem[tokenId].saleType == SaleType.Sale, "invalid sale type");
        require(ykzAmount == _tokenIdToSaleItem[tokenId].price, "invalid sale price");

        // send trading fee to devFund
        if( _tokenIdToSaleItem[tokenId].tradingFeeAmount > 0 ) {
            _ykz.safeTransferFrom(msg.sender, _devFund, _tokenIdToSaleItem[tokenId].tradingFeeAmount);            
            emit DevFundAddToken(FeeType.SaleTrading, block.timestamp, msg.sender, _tokenIdToSaleItem[tokenId].tradingFeeAmount);
        }

        _ykz.safeTransferFrom(msg.sender, _tokenIdToSaleItem[tokenId].seller, _tokenIdToSaleItem[tokenId].price.sub(_tokenIdToSaleItem[tokenId].tradingFeeAmount));

        emit SaleSuccessful(_tokenIdToSaleItem[tokenId].id, _tokenIdToSaleItem[tokenId].saleType, tokenId, _tokenIdToSaleItem[tokenId].seller, msg.sender, _tokenIdToSaleItem[tokenId].price, _tokenIdToSaleItem[tokenId].tradingFeeAmount);

        _withdraw(tokenId);        
    }

    function buyRentalItem(uint256 tokenId, uint256 ykzAmount, uint256 rentalDay) whenNotPaused nonReentrant external {
        require(_isOnSale(tokenId), "no sale");
        require(msg.sender != _tokenIdToSaleItem[tokenId].seller, "you are seller");
        require(_tokenIdToSaleItem[tokenId].saleType == SaleType.Rental, "invalid sale type");
        require(_maxRentalPeriod >= rentalDay, "max rental day over");
        require(ykzAmount == _tokenIdToSaleItem[tokenId].price.mul(rentalDay), "invalid rental price");

        uint256 rentalFee = _tokenIdToSaleItem[tokenId].tradingFeeAmount.mul(rentalDay);
        
        // send trading fee to devFund
        if( rentalFee > 0 ) {
            _ykz.safeTransferFrom(msg.sender, _devFund, rentalFee);            
            emit DevFundAddToken(FeeType.RentalTrading, block.timestamp, msg.sender,rentalFee);
        }

        _ykz.safeTransferFrom(msg.sender, _tokenIdToSaleItem[tokenId].seller, ykzAmount.sub(rentalFee));

        emit SaleSuccessful(_tokenIdToSaleItem[tokenId].id, _tokenIdToSaleItem[tokenId].saleType, tokenId, _tokenIdToSaleItem[tokenId].seller, msg.sender, _tokenIdToSaleItem[tokenId].price, _tokenIdToSaleItem[tokenId].tradingFeeAmount);
        
        _tokenOfLender[_tokenIdToSaleItem[tokenId].seller].add(tokenId);
        _tokenOfBorrower[msg.sender].add(tokenId);

        rentalIdIndex.increment();            
        Rental memory rental = Rental({
            id : rentalIdIndex.current(),
            lender : _tokenIdToSaleItem[tokenId].seller,
            borrower : msg.sender,
            rentalPrice : ykzAmount,
            rentalPeriod : rentalDay,
            endingTime : rentalDay.mul(86400).add(uint64(block.timestamp))
        });
        _tokenIdToRental[tokenId] = rental;
        totalRentalCount.increment();
        emit RentalSuccessful(_tokenIdToRental[tokenId].id, _tokenIdToSaleItem[tokenId].id, tokenId, _tokenIdToRental[tokenId].lender, _tokenIdToRental[tokenId].borrower, rentalDay, _tokenIdToRental[tokenId].endingTime);
        _removeSaleItem(tokenId);
    }

    function cancelSaleItem(uint256 tokenId) whenNotPaused onlySellerOrOperator(tokenId) external {
        require(_isOnSale(tokenId), "no sale");

        emit SaleCanceled(_tokenIdToSaleItem[tokenId].id, _tokenIdToSaleItem[tokenId].saleType, tokenId, _tokenIdToSaleItem[tokenId].seller);        

        _withdraw(tokenId);
    }    

    function retrieveRental(uint256 tokenId) whenNotPaused onlyLender(tokenId) external {
        require(_tokenIdToRental[tokenId].lender != address(0) , "no rental");
        require(_tokenIdToRental[tokenId].endingTime <= block.timestamp, "on rental period");
        require(_tokenIdToRental[tokenId].lender == msg.sender, "not a render");

        emit RetrieveRental(_tokenIdToRental[tokenId].id, tokenId, _tokenIdToRental[tokenId].lender, _tokenIdToRental[tokenId].borrower);

        _withdraw(tokenId);
    }

    function getTokenOfSeller(address seller) external view returns (uint256[] memory tokenIds) {
        uint256 length = _tokenOfSeller[seller].length();
        
        tokenIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = _tokenOfSeller[seller].at(i);
        }
        return tokenIds;
    }

    function getTokenOfLender(address lender) external view returns (uint256[] memory tokenIds) {
        uint256 length = _tokenOfLender[lender].length();
        
        tokenIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = _tokenOfLender[lender].at(i);
        }
        return tokenIds;
    }

    function getTokenOfBorrower(address borrower) external view returns (uint256[] memory tokenIds) {
        uint256 length = _tokenOfBorrower[borrower].length();
        
        tokenIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = _tokenOfBorrower[borrower].at(i);
        }
        return tokenIds;
    }        

    function isBorrower(uint256 tokenId, address borrower) external view returns (bool) {
        return (_tokenIdToRental[tokenId].borrower == borrower && _tokenIdToRental[tokenId].endingTime > block.timestamp);
    }

    function _deposit(uint256 tokenId) internal {
        _tokenOfSeller[msg.sender].add(tokenId);
        _ykzNft.safeTransferFrom(msg.sender, address(this), tokenId);        
    }

    function _removeSaleItem(uint256 tokenId) internal {
        _tokenOfSeller[_tokenIdToSaleItem[tokenId].seller].remove(tokenId);        
        delete _tokenIdToSaleItem[tokenId];
        totalSaleCount.decrement();
    }

    function _removeRentalItem(uint256 tokenId) internal {
        _tokenOfLender[_tokenIdToRental[tokenId].lender].remove(tokenId);
        _tokenOfBorrower[_tokenIdToRental[tokenId].borrower].remove(tokenId);        
        delete _tokenIdToRental[tokenId];
        totalRentalCount.decrement();
    }

    function _withdraw(uint256 tokenId) internal {
        if( _tokenIdToSaleItem[tokenId].id > 0 ) {
            _removeSaleItem(tokenId);
        }

        if( _tokenIdToRental[tokenId].id > 0 ) {
            _removeRentalItem(tokenId);
        }

        _ykzNft.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function _isOnSale(uint256 tokenId) internal view returns (bool) {
        return _tokenIdToSaleItem[tokenId].id > 0;
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