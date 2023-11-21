// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Marketplace is Ownable {
    // Khai báo Id Order
    using Counters for Counters.Counter;
    Counters.Counter private _orderIdCounter;
    // Appcet all token ERC20
    using EnumerableSet for EnumerableSet.AddressSet;
    // Declare a set state variable
    EnumerableSet.AddressSet private _supportPaymentTokens;

    // Khai báo các tham số cần thiết cho order
    struct Order {
        address seller;
        address buyer;
        address paymentToken;
        uint256 tokenId;
        uint256 price;
    }

    // khai báo NFT readonly
    IERC721 public immutable nftContract;
    // mapping order
    mapping(uint256 => Order) orders;
    uint256 public feeDecimal;
    // Phí giao dịch
    uint256 public feeRate;
    // Địa chỉ ví nhận phí
    address public feeRecipent;

    // >>>>>>>>>>>>> KHAI BÁO CÁC EVENT <<<<<<<<<<<<<<<<<<

    //  1. Order
    event OrderAdded(
        uint256 indexed orderId,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        address tokenPayment
    );

    // 2. Huỷ Order
    event OrderCancled(uint256 indexed orderId);

    // 3. Kiểm tra order đúng người mua - người bán - tt của order?
    event OrderMatcher(
        uint256 indexed orderId,
        address indexed seller,
        uint256 indexed tokenId,
        address buyer,
        uint256 price,
        address tokenPayment
    );

    // 4. Update phí sau khi thực hiện order
    event FeeRateUpdate(uint256 feeDecimal, uint256 feeRate);

    constructor(
        address nftAddress_,
        uint256 feeDecimal_,
        uint256 feeRate_,
        address feeRecipient_
    ) {
        require(
            nftAddress_ != address(0),
            "NFTMarketplace: nftAddress_ is zero address"
        );

        nftContract = IERC721(nftAddress_);
        _updateFeeRecipent(feeRecipient_);
        _updateFeeRate(feeRate_, feeDecimal_);
        _orderIdCounter.increment();
    }

    // Update địa chỉ nhận fee
    function _updateFeeRecipent(address feeRecipient_) internal {
        require(
            feeRecipient_ != address(0),
            "NFTMarketplace: feeRecipient_ is zero address"
        );
        feeRecipent = feeRecipient_;
    }

    // Update Fee
    function _updateFeeRate(uint256 feeRate_, uint256 feeDecimal_) internal {
        // Phí Rate < 100%
        require(
            feeRate_ < 10 ** (feeDecimal_ + 2),
            "NFTMarketplace: bad fee rate"
        );
        feeRate = feeRate_;
        feeDecimal = feeDecimal_;
        emit FeeRateUpdate(feeRate_, feeDecimal_);
    }

    // Tính toán Fee
    function _caculateFee(uint256 orderId) private view returns (uint256) {
        if (feeRate == 0) return 0;
        // Khai báo order
        Order storage _order = orders[orderId];
        // Phần trăm phí
        return (feeRate * _order.price) / 10 ** (feeDecimal + 2);
    }

    // Kiểm tra paymentToken đc support?
    function isPaymentTokenSupport(
        address paymentToken_
    ) private view returns (bool) {
        return _supportPaymentTokens.contains(paymentToken_);
    }

    // modifier paymentToken support
    modifier onlyPaymentTokenSupported(address paymentToken_) {
        require(
            isPaymentTokenSupport(paymentToken_),
            "NFTMarketplace: unsupport payment token"
        );
        // tiếp tục ...
        _;
    }

    // Thêm payment token vào MPL
    function addPaymentToken(address paymentToken_) external onlyOwner {
        require(
            paymentToken_ != address(0),
            "NFTMarketplace: paymentToken_ is zero address"
        );

        require(
            _supportPaymentTokens.add(paymentToken_),
            "NFTMarketplace: paymentToken_ is already supported"
        );
    }

    // Thực hiện order
    function addOrder(
        uint256 tokenId_,
        address paymentToken_,
        uint256 price_
    ) public onlyPaymentTokenSupported(paymentToken_) {
        require(
            _msgSender() == nftContract.ownerOf(tokenId_),
            "NFTMarketplace: sender is owner of token"
        );

        require(
            nftContract.getApproved(tokenId_) == address(this) ||
                nftContract.isApprovedForAll(_msgSender(), address(this)),
            "NFTMarketplace: nftContract is Approved"
        );

        require(price_ > 0, "NFTMarketplace: price is bigger than 0");
        uint256 orderId_ = _orderIdCounter.current();
        orders[orderId_] = Order(
            _msgSender(),
            address(0),
            paymentToken_,
            tokenId_,
            price_
        );
        _orderIdCounter.increment();
        nftContract.transferFrom(_msgSender(), address(this), tokenId_);
        emit OrderAdded(
            orderId_,
            _msgSender(),
            tokenId_,
            price_,
            paymentToken_
        );
    }

    // Huy order
    function cancleOrder(uint256 orderId_) public {
        Order storage _order = orders[orderId_];
        require(
            _order.buyer == address(0),
            "NFTMarketplace: buyer must be zero"
        );

        require(
            _order.seller == _msgSender(),
            "NFTMarketplace: _msgSender must be owner"
        );

        uint256 tokenId_ = _order.tokenId;
        nftContract.transferFrom(address(this), _msgSender(), tokenId_);
        delete orders[orderId_];
        emit OrderCancled(orderId_);
    }

    // Thực hiện order
    function excuteOrder(uint256 orderId_) public {
        Order storage _order = orders[orderId_];
        require(_order.price > 0, "NFTMarketplace: price is bigger than 0");
        require(
            _order.seller != _msgSender(),
            "NFTMarketplace: seller is different from buyer"
        );
        require(
            _order.buyer == address(0),
            "NFTMarketplace: buyer must be address 0"
        );

        _order.buyer = _msgSender();
        // 1.Tính fee giao dịch
        uint256 _feeAmount = _caculateFee(orderId_);
        // 2.Chuyển phí giao dịch vào feeRecipent
        if (_feeAmount > 0) {
            IERC20(_order.paymentToken).transferFrom(
                _msgSender(),
                feeRecipent,
                _feeAmount
            );
        }
        // 3. Chuyển tiến đến người bán
        IERC20(_order.paymentToken).transferFrom(
            _msgSender(),
            _order.seller,
            _order.price - _feeAmount
        );
        // 4. Chuyển NFT tới người mua
        nftContract.transferFrom(address(this), _msgSender(), _order.tokenId);
        emit OrderMatcher(
            orderId_,
            _order.seller,
            _order.tokenId,
            _msgSender(),
            _order.price,
            _order.paymentToken
        );
    }
}
