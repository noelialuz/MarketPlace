// SPDX-License-Identifier: MIT 
pragma solidity 0.8.35;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/NFTMarketplace.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }
}

contract NFTMarketplaceTest is Test {

    NFTMarketplace marketplace;
    MockNFT nft;
    address deployer = vm.addr(1); 
    address user = vm.addr(2);
    address feeAccount = vm.addr(4);
    uint256 feePercent = 250;
    uint256 tokenId = 0;

    function setUp() public {
        vm.startPrank(deployer);
        marketplace = new NFTMarketplace(feeAccount, feePercent);
        nft = new MockNFT();
        vm.stopPrank();

        vm.startPrank(user);
        nft.mint(user, tokenId);
        vm.stopPrank();
    }

    function testMintNFT() public view {
        address ownerOf = nft.ownerOf(tokenId);
        assert(ownerOf == user);
    }

    function testShouldRevertIfPriceIsZero() public {
        vm.startPrank(user);

        vm.expectRevert("Price can not be 0");
        marketplace.listNFT(address(nft), tokenId, 0);

        vm.stopPrank();
    }

    function testShouldRevertIfNotOwner() public {
        vm.startPrank(user);

        address user2_ = vm.addr(3);
        uint256 tokenId_ = 1;
        nft.mint(user2_, tokenId_);

        vm.expectRevert("You are not the owner of the NFT");
        marketplace.listNFT(address(nft), tokenId_, 1);

        vm.stopPrank();
    }

    function testShouldRevertIfNotApproved() public {
        vm.startPrank(user);
        
        vm.expectRevert("Marketplace not approved");
        marketplace.listNFT(address(nft), tokenId, 1e18);
        
        vm.stopPrank();
    }

    function testListNFTCorreclty() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();
    }

    function testListShouldRevertIfNotOwner() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);

        vm.expectRevert("You are not the listing owner");
        marketplace.cancelList(address(nft), tokenId);
        vm.stopPrank();
    }

    function testCancelListShouldWorkCorrectly() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        marketplace.cancelList(address(nft), tokenId);
        (address sellerAfter2,,,)= marketplace.listing(address(nft), tokenId);
        assert(sellerAfter2 == address(0));

        vm.stopPrank();
    }

    function testCanNotBuyUnlistedNFT() public {
        address user2 = vm.addr(3);
        vm.startPrank(user2);

        vm.expectRevert("Listing not exists");
        marketplace.buyNFT(address(nft), tokenId);

        vm.stopPrank();
    }

    function testCanNotBuyWithIncorrectPay() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        uint256 price = 1e18;
        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, price);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        vm.deal(user2, price);

        vm.expectRevert("Incorrect price");
        marketplace.buyNFT{value: price - 1}(address(nft), tokenId);

        vm.stopPrank();
    }

    function testShouldBuyNFTCorrectlyWithFees() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        uint256 price = 1e18;
        marketplace.listNFT(address(nft), tokenId, price);
        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        vm.deal(user2, price);
        
        uint256 balanceBefore = address(user).balance;
        uint256 feeBalanceBefore = address(feeAccount).balance;
        
        marketplace.buyNFT{value: price}(address(nft), tokenId);
        
        uint256 expectedFee = (price * feePercent) / 10000;
        uint256 expectedSellerAmount = price - expectedFee;

        assert(nft.ownerOf(tokenId) == user2);
        assert(address(user).balance == balanceBefore + expectedSellerAmount);
        assert(address(feeAccount).balance == feeBalanceBefore + expectedFee);
      
        vm.stopPrank();
    }

    function testUpdatePriceCorrectly() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);

        uint256 newPrice = 2e18;
        marketplace.updatePrice(address(nft), tokenId, newPrice);

        (,,,uint256 priceAfter) = marketplace.listing(address(nft), tokenId);
        assert(priceAfter == newPrice);
        vm.stopPrank();
    }

    function testUpdatePriceShouldRevertIfPriceIsZero() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);

        vm.expectRevert("Price can not be 0");
        marketplace.updatePrice(address(nft), tokenId, 0);
        vm.stopPrank();
    }

    // New tests
    function testUpdatePriceShouldRevertIfNotOwner() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        vm.expectRevert("You are not the listing owner");
        marketplace.updatePrice(address(nft), tokenId, 2e18);
        vm.stopPrank();
    }

    function testConstructorRevertsIfFeeAccountIsZero() public {
        vm.startPrank(deployer);
        vm.expectRevert("Invalid fee account");
        new NFTMarketplace(address(0), 250);
        vm.stopPrank();
    }

    function testConstructorRevertsIfFeePercentExceedsLimit() public {
        vm.startPrank(deployer);
        vm.expectRevert("Fee cannot exceed 10%");
        new NFTMarketplace(feeAccount, 1001);
        vm.stopPrank();
    }

    function testSetFeeAccountCorrectly() public {
        vm.startPrank(deployer);
        address newFeeAccount = vm.addr(5);
        marketplace.setFeeAccount(newFeeAccount);
        assert(marketplace.feeAccount() == newFeeAccount);
        vm.stopPrank();
    }

    function testSetFeeAccountRevertsIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert("Not the contract owner");
        marketplace.setFeeAccount(vm.addr(5));
        vm.stopPrank();
    }

    function testSetFeeAccountRevertsIfZeroAddress() public {
        vm.startPrank(deployer);
        vm.expectRevert("Invalid address");
        marketplace.setFeeAccount(address(0));
        vm.stopPrank();
    }

    function testSetFeePercentCorrectly() public {
        vm.startPrank(deployer);
        uint256 newFeePercent = 500;
        marketplace.setFeePercent(newFeePercent);
        assert(marketplace.feePercent() == newFeePercent);
        vm.stopPrank();
    }

    function testSetFeePercentRevertsIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert("Not the contract owner");
        marketplace.setFeePercent(500);
        vm.stopPrank();
    }

    function testSetFeePercentRevertsIfExceedsLimit() public {
        vm.startPrank(deployer);
        vm.expectRevert("Fee cannot exceed 10%");
        marketplace.setFeePercent(1001);
        vm.stopPrank();
    }

    function testRemoveStaleListingIfOwnerChanged() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        
        address user2 = vm.addr(3);
        nft.transferFrom(user, user2, tokenId);
        vm.stopPrank();

        vm.startPrank(user2);
        marketplace.removeStaleListing(address(nft), tokenId);
        (address seller,,, ) = marketplace.listing(address(nft), tokenId);
        assert(seller == address(0));
        vm.stopPrank();
    }

    function testRemoveStaleListingIfApprovalRemoved() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        
        nft.approve(address(0), tokenId);
        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        marketplace.removeStaleListing(address(nft), tokenId);
        (address seller,,, ) = marketplace.listing(address(nft), tokenId);
        assert(seller == address(0));
        vm.stopPrank();
    }

    function testRemoveStaleListingRevertsIfListingDoesNotExist() public {
        vm.startPrank(user);
        vm.expectRevert("Listing does not exist");
        marketplace.removeStaleListing(address(nft), tokenId);
        vm.stopPrank();
    }

    function testRemoveStaleListingRevertsIfListingIsStillValid() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        vm.expectRevert("Listing is still valid and active");
        marketplace.removeStaleListing(address(nft), tokenId);
        vm.stopPrank();
    }

    function testListNFTWithApprovalForAll() public {
    vm.startPrank(user);
    nft.setApprovalForAll(address(marketplace), true);

    marketplace.listNFT(address(nft), tokenId, 1e18);
    (address seller,,,) = marketplace.listing(address(nft), tokenId);
    
    assert(seller == user);
    vm.stopPrank();
}

function testRemoveStaleListingWhenOwnerChangedAndApprovalRemoved() public {
    vm.startPrank(user);
    nft.approve(address(marketplace), tokenId);
    marketplace.listNFT(address(nft), tokenId, 1e18);
    
    address user2 = vm.addr(3);
    nft.transferFrom(user, user2, tokenId);
    vm.stopPrank();

    vm.startPrank(user2);
    nft.approve(address(0), tokenId);
    vm.stopPrank();

    address user3 = vm.addr(5);
    vm.startPrank(user3);
    marketplace.removeStaleListing(address(nft), tokenId);
    (address seller,,,) = marketplace.listing(address(nft), tokenId);
    assert(seller == address(0));
    vm.stopPrank();
    }
}