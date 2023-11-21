// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TokenSale is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct List {
        uint256 tokenId;
        address payable seller;
        address buyer;
        address nftContract;
        uint256 price;
    }

    mapping(uint256 => List) public listNFT;

    event BuyNFT(
        uint256 indexed tokenId,
        address seller,
        address buyer,
        address indexed nftContract,
        uint256 price
    );

    function buyNFT(uint256 _tokenId) public payable {
        List storage _nft = listNFT[_tokenId];
        require(_nft.price > 0, "Token Sale: Price is bigger than 0");
        require(
            _nft.seller != _msgSender(),
            "Token Sale: seller is different from buyer"
        );
        require(
            _nft.buyer == address(0),
            "Token Sale: buyer must be address 0"
        );

        _nft.seller.transfer(_nft.price);
        IERC721(_nft.nftContract).transferFrom(
            address(this),
            msg.sender,
            _nft.tokenId
        );

        emit BuyNFT(
            _nft.tokenId,
            _nft.seller,
            msg.sender,
            _nft.nftContract,
            _nft.price
        );
    }
}
