// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Batman is ERC721, Ownable {
    // Khai báo Id Order
    using Counters for Counters.Counter;
    Counters.Counter private _nftIdCounter;
    // Khai báo token Url
    string private _tokenUrl;

    constructor() ERC721("Batman", "BAT") {
        _mint(msg.sender, 1);
    }

    function mint(address _to) public onlyOwner returns (uint256) {
        _nftIdCounter.increment();
        uint256 _tokenId = _nftIdCounter.current();
        _mint(_to, _tokenId);
        return _tokenId;
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenUrl;
    }

    function updateBaseUri(string memory tokenUrl) public onlyOwner {
        _tokenUrl = tokenUrl;
    }
}
