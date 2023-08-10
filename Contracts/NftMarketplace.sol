// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is IERC721Receiver, Ownable {
    using SafeMath for uint256;

    uint256 private constant FEE_PERCENTAGE = 10; // 10% fee
    uint256 private constant ONE_HUNDRED = 100;

    // Struct to hold auction data
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        uint256 highestBid;
        address highestBidder;
        bool isActive;
    }

    // Mapping to hold auction data
    mapping(address => mapping(uint256 => Auction)) public auctions;

    // Event to notify when a new auction is created
    event AuctionCreated(address indexed tokenAddress, uint256 indexed tokenId, uint256 reservePrice, uint256 startTime, uint256 endTime);

    // Event to notify when a bid is placed
    event BidPlaced(address indexed tokenAddress, uint256 indexed tokenId, address indexed bidder, uint256 amount);

    // Event to notify when an auction is ended
    event AuctionEnded(address indexed tokenAddress, uint256 indexed tokenId, address indexed winner, uint256 amount);

    // Function to create a new auction
    function createAuction(address tokenAddress, uint256 tokenId, uint256 reservePrice, uint256 duration) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Not token owner");

        Auction storage auction = auctions[tokenAddress][tokenId];
        require(!auction.isActive, "Auction already exists");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime.add(duration);

        auction.seller = msg.sender;
        auction.tokenId = tokenId;
        auction.reservePrice = reservePrice;
        auction.startTime = startTime;
        auction.endTime = endTime;
        auction.isActive = true;

        IERC721(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(tokenAddress, tokenId, reservePrice, startTime, endTime);
    }

    // Function to place a bid
    function placeBid(address tokenAddress, uint256 tokenId) external payable {
        Auction storage auction = auctions[tokenAddress][tokenId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp >= auction.startTime && block.timestamp <= auction.endTime, "Auction not active");
        require(msg.value >= auction.reservePrice, "Bid below reserve price");
        require(msg.value > auction.highestBid, "Bid below current highest bid");

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid); // Refund previous highest bidder
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(tokenAddress, tokenId, msg.sender, msg.value);
    }

    // Function to end an auction
    function endAuction(address tokenAddress, uint256 tokenId) external {
        Auction storage auction = auctions[tokenAddress][tokenId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp > auction.endTime, "Auction not ended yet");
        require(msg.sender == auction.seller || msg.sender == owner(), "Not authorized");

        if (auction.highestBidder != address(0)) {
            uint256 feeAmount = auction.highestBid.mul(FEE_PERCENTAGE).div(ONE_HUNDRED);
            uint256 sellerAmount = auction.highestBid.sub(feeAmount);

            payable(auction.seller).transfer(sellerAmount);
            payable(owner()).transfer(feeAmount);

            IERC721(tokenAddress).safeTransferFrom(address(this), auction.highestBidder, tokenId);

            emit AuctionEnded(tokenAddress, tokenId, auction.highestBidder, auction.highestBid);
        } else {
            IERC721(tokenAddress).safeTransferFrom(address(this), auction.seller, tokenId);
        }

        delete auctions[tokenAddress][tokenId];
    }

    // Function to handle receiving ERC721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
