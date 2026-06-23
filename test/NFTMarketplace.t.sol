pragma solidity 0.8.24;

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
    uint256 tokenId = 0;

    function setUp() public {
        vm.startPrank(deployer);
        marketplace = new NFTMarketplace();
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

    function testListNFTCorreclty() public {
        vm.startPrank(user);

        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, 1e18);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        vm.stopPrank();
    }

    function testListShouldRevertIfNotOwner() public {
        vm.startPrank(user);

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

    function testShouldBuyNFTCorrectly() public {
        vm.startPrank(user);

        uint256 price = 1e18;
        (address sellerBefore,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.listNFT(address(nft), tokenId, price);
        (address sellerAfter,,,)= marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);

        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();

        address user2 = vm.addr(3);
        vm.startPrank(user2);
        vm.deal(user2, price);
        
        uint256 balanceBefore = address(user).balance;
        address ownerBefore = nft.ownerOf(tokenId);
        (address sellerBefore2,,,)= marketplace.listing(address(nft), tokenId);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
        (address sellerAfter2,,,)= marketplace.listing(address(nft), tokenId);
        address ownerAfter = nft.ownerOf(tokenId);
        uint256 balanceAfter = address(user).balance;

        assert(sellerBefore2 == user && sellerAfter2 == address(0));
        assert(ownerBefore == user && ownerAfter == user2);
        assert(balanceAfter == balanceBefore + price);
      
        vm.stopPrank();
    }
}