// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TimedAuction
 * @dev A basic auction system with time constraints
 */
contract TimedAuction {
    struct Auction {
        address payable seller;
        string itemDescription;
        uint256 startingPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 highestBid;
        address payable highestBidder;
        bool ended;
        bool itemClaimed;
    }
    
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    
    uint256 public auctionCount;
    
    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemDescription, uint256 startingPrice, uint256 startTime, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event FundsWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event ItemClaimed(uint256 indexed auctionId, address indexed winner);
    
    /**
     * @dev Create a new auction
     * @param _itemDescription Description of the item being auctioned
     * @param _startingPrice Minimum bid amount in wei
     * @param _startDelayInMinutes Time until auction starts (in minutes)
     * @param _durationInMinutes Duration of the auction (in minutes)
     */
    function createAuction(
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _startDelayInMinutes,
        uint256 _durationInMinutes
    ) public {
        require(_startingPrice > 0, "Starting price must be greater than zero");
        require(_durationInMinutes > 0, "Duration must be greater than zero");
        
        uint256 startTime = block.timestamp + (_startDelayInMinutes * 1 minutes);
        uint256 endTime = startTime + (_durationInMinutes * 1 minutes);
        
        auctionCount++;
        
        auctions[auctionCount] = Auction({
            seller: payable(msg.sender),
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            startTime: startTime,
            endTime: endTime,
            highestBid: 0,
            highestBidder: payable(address(0)),
            ended: false,
            itemClaimed: false
        });
        
        emit AuctionCreated(auctionCount, msg.sender, _itemDescription, _startingPrice, startTime, endTime);
    }
    
    /**
     * @dev Place a bid on an auction
     * @param _auctionId ID of the auction
     */
    function placeBid(uint256 _auctionId) public payable {
        Auction storage auction = auctions[_auctionId];
        
        require(auction.seller != address(0), "Auction does not exist");
        require(block.timestamp >= auction.startTime, "Auction has not started yet");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(!auction.ended, "Auction has been finalized");
        require(msg.sender != auction.seller, "Seller cannot bid on their own auction");
        
        uint256 bidAmount = msg.value;
        
        if (auction.highestBid == 0) {
            // First bid must be at least the starting price
            require(bidAmount >= auction.startingPrice, "Bid must be at least the starting price");
        } else {
            // Subsequent bids must be higher than the current highest bid
            require(bidAmount > auction.highestBid, "Bid must be higher than current highest bid");
            
            // Record the previous highest bidder's amount for withdrawal
            pendingReturns[_auctionId][auction.highestBidder] += auction.highestBid;
        }
        
        auction.highestBid = bidAmount;
        auction.highestBidder = payable(msg.sender);
        
        emit BidPlaced(_auctionId, msg.sender, bidAmount);
    }
    
    /**
     * @dev End an auction and determine the winner
     * @param _auctionId ID of the auction
     */
    function endAuction(uint256 _auctionId) public {
        Auction storage auction = auctions[_auctionId];
        
        require(auction.seller != address(0), "Auction does not exist");
        require(!auction.ended, "Auction already ended");
        require(
            msg.sender == auction.seller || block.timestamp >= auction.endTime,
            "Only seller can end before deadline"
        );
        
        auction.ended = true;
        
        // If there was at least one bid
        if (auction.highestBidder != address(0)) {
            // Transfer funds to the seller
            auction.seller.transfer(auction.highestBid);
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }
    
    /**
     * @dev Withdraw bids that were outbid
     * @param _auctionId ID of the auction
     */
    function withdrawFunds(uint256 _auctionId) public {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingReturns[_auctionId][msg.sender] = 0;
        
        payable(msg.sender).transfer(amount);
        
        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }
    
    /**
     * @dev Mark an item as claimed by the winner
     * @param _auctionId ID of the auction
     */
    function confirmItemClaimed(uint256 _auctionId) public {
        Auction storage auction = auctions[_auctionId];
        
        require(auction.ended, "Auction must be ended");
        require(msg.sender == auction.seller, "Only seller can confirm item claim");
        require(!auction.itemClaimed, "Item already claimed");
        require(auction.highestBidder != address(0), "No winning bidder");
        
        auction.itemClaimed = true;
        
        emit ItemClaimed(_auctionId, auction.highestBidder);
    }
    

    function getAuctionDetails(uint256 _auctionId) public view returns (
        address seller,
        string memory itemDescription,
        uint256 startingPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 highestBid,
        address highestBidder,
        bool ended,
        bool itemClaimed
    ) {
        Auction storage auction = auctions[_auctionId];
        require(auction.seller != address(0), "Auction does not exist");
        
        return (
            auction.seller,
            auction.itemDescription,
            auction.startingPrice,
            auction.startTime,
            auction.endTime,
            auction.highestBid,
            auction.highestBidder,
            auction.ended,
            auction.itemClaimed
        );
    }
}