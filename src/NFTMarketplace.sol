// SPDX-License-Identifier: MIT 

pragma solidity 0.8.35;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is ReentrancyGuard {

    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    address public owner;
    address public feeAccount; 
    uint256 public feePercent; 

    mapping(address => mapping(uint256 => Listing)) public listing;

    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
    event NFTPriceUpdated(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 newPrice);
    event FeeAccountChanged(address indexed oldAccount, address indexed newAccount);
    event FeePercentChanged(uint256 oldPercent, uint256 newPercent);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(address feeAccount_, uint256 feePercent_) {
        owner = msg.sender;
        require(feeAccount_ != address(0), "Invalid fee account");
        require(feePercent_ <= 1000, "Fee cannot exceed 10%"); 
        feeAccount = feeAccount_;
        feePercent = feePercent_;
    }

    function setFeeAccount(address feeAccount_) external onlyOwner {
        require(feeAccount_ != address(0), "Invalid address");
        emit FeeAccountChanged(feeAccount, feeAccount_);
        feeAccount = feeAccount_;
    }

    function setFeePercent(uint256 feePercent_) external onlyOwner {
        require(feePercent_ <= 1000, "Fee cannot exceed 10%");
        emit FeePercentChanged(feePercent, feePercent_);
        feePercent = feePercent_;
    }

    function listNFT(address nftAddress_, uint256 tokenId_, uint256 price_) external nonReentrant {
        require(price_ > 0, "Price can not be 0");
        address owner_ = IERC721(nftAddress_).ownerOf(tokenId_);
        require(owner_ == msg.sender, "You are not the owner of the NFT");
        require(
            IERC721(nftAddress_).getApproved(tokenId_) == address(this) || 
            IERC721(nftAddress_).isApprovedForAll(msg.sender, address(this)), 
            "Marketplace not approved"
        );

        Listing memory listing_ = Listing({
            seller: msg.sender,
            nftAddress: nftAddress_,
            tokenId: tokenId_,
            price: price_
        });

        listing[nftAddress_][tokenId_] = listing_;

        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);
    }

    function buyNFT(address nftAddress_, uint256 tokenId_) external payable nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        require(listing_.price > 0, "Listing not exists");
        require(msg.value == listing_.price, "Incorrect price");

        delete listing[nftAddress_][tokenId_];

        uint256 feeAmount = (msg.value * feePercent) / 10000;
        uint256 sellerAmount = msg.value - feeAmount;

        IERC721(nftAddress_).safeTransferFrom(listing_.seller, msg.sender, listing_.tokenId);

        if (feeAmount > 0) {
            (bool successFee, ) = feeAccount.call{value: feeAmount}("");
            require(successFee, "Fee transfer failed");
        }

        (bool successSeller, ) = listing_.seller.call{value: sellerAmount}("");
        require(successSeller, "Seller transfer failed");
        
        emit NFTSold(msg.sender, listing_.seller, listing_.nftAddress, listing_.tokenId, listing_.price);
    }

    function cancelList(address nftAddress_, uint256 tokenId_) external nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        require(listing_.seller == msg.sender, "You are not the listing owner");

        delete listing[nftAddress_][tokenId_];

        emit NFTCancelled(msg.sender, nftAddress_, tokenId_);
    }

    function updatePrice(address nftAddress_, uint256 tokenId_, uint256 newPrice_) external nonReentrant {
        require(newPrice_ > 0, "Price can not be 0");
        Listing storage listing_ = listing[nftAddress_][tokenId_];
        require(listing_.seller == msg.sender, "You are not the listing owner");

        listing_.price = newPrice_;

        emit NFTPriceUpdated(msg.sender, nftAddress_, tokenId_, newPrice_);
    }

    function removeStaleListing(address nftAddress_, uint256 tokenId_) external nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        require(listing_.price > 0, "Listing does not exist");

        address currentOwner = IERC721(nftAddress_).ownerOf(tokenId_);
        
        bool isNoLongerOwner = currentOwner != listing_.seller;
        bool isNotApproved = IERC721(nftAddress_).getApproved(tokenId_) != address(this) && 
                             !IERC721(nftAddress_).isApprovedForAll(listing_.seller, address(this));

        require(isNoLongerOwner || isNotApproved, "Listing is still valid and active");

        delete listing[nftAddress_][tokenId_];
        
        emit NFTCancelled(listing_.seller, nftAddress_, tokenId_);
    }
}