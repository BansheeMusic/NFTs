// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract RoyaltyERC721 is ERC721, ERC721URIStorage, IERC2981 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint256 private constant ROYALTY_PERCENTAGE = 15;
    address payable private _royaltyRecipient;

    constructor(string memory name, string memory symbol, address payable royaltyRecipient) ERC721(name, symbol) {
        _royaltyRecipient = royaltyRecipient;
    }

    function mint(address to, string memory tokenURI) public {
        _tokenIdCounter.increment();
        uint256 newItemId = _tokenIdCounter.current();
        _safeMint(to, newItemId);
        _setTokenURI(newItemId, tokenURI);
    }

    // Override ERC721URIStorage's _burn to keep tokenURI storage
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // Override ERC721URIStorage's tokenURI to keep tokenURI storage
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // Implement IERC2981's royaltyInfo
    function royaltyInfo(uint256, uint256 salePrice) external view override returns (address, uint256) {
        uint256 royaltyAmount = (salePrice * ROYALTY_PERCENTAGE) / 100;
        return (_royaltyRecipient, royaltyAmount);
    }

    // Implement IERC2981's supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC721, ERC721URIStorage) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
