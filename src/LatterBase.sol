// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Timers.sol";
import "src/interface/ILatterBase.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";


// List and Sell NFTs 
// include marketplace fee
// include installment amount
// include payment amount
// include time component and expiry

/// @title Latter Base
/// @author William Phan
/// @notice Pay-in-four model. 4 payments made every 2 weeks for an NFT
/// @dev All function calls are currently implemented without side effects
/// @custom:experimental This is an experimental contract.

// Set the contract to be owned
contract LatterBase is ILatterBase, IERC721Receiver{
    using Timers for Timers.Timestamp;
    using Counters for Counters.Counter;

    // Timer to track the expiration of an action or event
    Timers.Timestamp public timer;

    // counts the number of listings - also the listingId, starts from 1
    Counters.Counter private listingCounter;

    // counts the number of sold listings
    Counters.Counter private listingSoldCounter;

    // The ERC721 token contract
    IERC721 public nftContract;

    // The address of the marketplace contract owner
    address public marketplaceOwner;

    // The due date for each payment
    uint256 public installmentTimeLimit;

    // The marketplace transaction fee (0.5%)
    uint256 public transactionFee = uint256(0.005 * 10**18);

    mapping(uint256 => Listing) private listings;

    // checks if address is valid
    mapping(uint256 => address) public approved;

    // The constructor with settings
    constructor(address _marketplaceOwner) {
        marketplaceOwner = _marketplaceOwner;
    }

     // Function to list an NFT for sale
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 listingPrice
    ) external {
        // price to list cannot be negaive
        if (listingPrice <= 0) {
            revert PriceBelowZero();
        }

        IERC721 nft = IERC721(nftAddress);

        // increment listing counter
        listingCounter.increment();

        // current incremented token listing
        Listing storage listing = listings[tokenId];

        // check if token isn't already listed
        if (listing.state != State.ForSale) {
            revert TokenAlreadyListed();
        }

        // set installment price
        // installment price = listing price divided by 4
        uint256 installmentPrice = listingPrice / 4;

        // current installment counter = 0
        uint256 installmentCounter = 0;

        // inputs for new listing
        Listing memory newListing = Listing(
            false,
            installmentCounter,
            tokenId,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            block.timestamp,
            // changes the state to for sale
            State.ForSale
        );

        listings[tokenId] = newListing;

          // emit event
        emit ListingCreated(
            false,
            installmentCounter,
            tokenId,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            block.timestamp,
            State.ForSale
        );
        
        // transfers NFT from caller to contract address
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
    }

     /// DELETE LISTING ///

   function deleteListing(uint256 tokenId) external {

        // grab token listing
        Listing storage listing = listings[tokenId];

        // check if the caller is the owner of the listing
        if (msg.sender != listing.seller) {
            revert UserNotApproved();
        }

        // // Decrement the NFT listing counter
        // listingCounter.decrement();

        // transfer the NFT back to the seller
        IERC721(listing.nftAddress).safeTransferFrom(address(this), listing.seller, listing.tokenId);

        // otherwise, remove the listing
        delete listings[tokenId];

        listingCounter.decrement();

        // emit listing has been removed by reseting to default values and zero address
        emit ListingDeleted(
            true,
            listing.tokenId,
            listing.nftAddress,
            payable(msg.sender),
            block.timestamp,
            State.NotForSale
        );
   }

    // installment + marketplace fee of .05%
    // make sure first payer will stay the first payer until after late time
    function makePayment(uint256 tokenId) public payable {
        Listing storage listing = listings[tokenId];
        // checks if installment number is greater than 1 to see
        // if there was not an existing buyer
        // otherwise revert
        if (listing.installmentNumber > 1 && msg.sender != listing.buyer) {
            revert UserNotApproved();
        }

        // set the buyer for first installment
        if (listing.installmentNumber == 0) {
            listing.buyer = payable(msg.sender);
        }
        
        // **check this**
        // check if initial buyer is msg.sender
        // check if installment number is between not less than 1 and not greater than 4
        if (listing.buyer != msg.sender || listing.installmentNumber < 1 && listing.installmentNumber > 4){
            revert UserNotApproved();
        }

        // Check if all 4 installment payments have been made
        // if so, transfer the NFT
        if (listing.installmentNumber == 4) {
            // change the listing state to NotForSale
            listing.state = State.NotForSale;
            // Transfer ownership of the NFT from the seller to the msg.sender
            IERC721(listing.nftAddress).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId
        );

        // Increment the number of installment payments made
        listing.installmentNumber++;

        // Calculate the transaction fee
        uint256 fee = listing.installmentPrice * transactionFee;

        // Check that the correct payment amount is received
        // if less, then revert
        // installmentPrice + the transaction fee
        if (msg.value < listing.installmentPrice + fee) {
            revert IncorrectInstallmentAmountPlusFee();
        }

        // set payment active
        listing.state = State.PaymentActive;

        // increase deadline of 14 days until next installment
        timer.setDeadline(uint64(block.timestamp + 14 days));

        uint256 deadline = timer.getDeadline();
        uint256 timeLeft = deadline - block.timestamp;

        // transfers part of the value (calculated fee) that was sent to the marketplace
        payable(address(this)).transfer(fee);
        // transfers part of the value (calculated installmentPrice) that was sent to the seller
        payable(listing.seller).transfer(listing.installmentPrice);

        emit ListingInstallmentPaid(
            false,
            listing.installmentNumber,
            listing.tokenId,
            listing.nftAddress,
            listing.seller,
            listing.buyer,
            listing.listingPrice,
            listing.installmentPrice,
            timeLeft,
            State.NotForSale
        );

            emit PaidOff(
                true,
                listing.installmentNumber,
                listing.tokenId,
                listing.nftAddress,
                listing.seller,
                listing.buyer,
                listing.listingPrice,
                listing.installmentPrice,
                timeLeft,
                State.NotForSale
            );
        }
        // if the listing is expired and the current installment paid is less than 4,
        // revert and remove operator
        if (
            listing.isExpired == true &&
            listing.installmentNumber <= 4 || listing.isExpired == true
        ) {
            revertNFT(listing.tokenId);
        }
    }

      function getListingInfo(uint tokenId) public view returns (Listing memory){
          return listings[tokenId];
    }

    // function to get the total installment amount due
    // installment + the transaction fee
    function getInstallmentAmountPlusFee(uint256 tokenId)
        public
        view
        returns (uint256 pricePlusFee)
    {
        Listing storage listing = listings[tokenId];
        // calculate the transaction fee
        uint256 fee = listing.installmentPrice * transactionFee;
        // add the transaction fee to the installment amount
        uint256 totalAmountDue = listings[tokenId].installmentPrice + fee;
        return totalAmountDue;
    }

    // function to get the installment amount only without transaction fee
    function getInstallmentAmountOnly(uint256 tokenId)
        public
        view
        returns (uint256 price)
    {
        Listing storage listing = listings[tokenId];
        // calculate the transaction fee
        uint256 installmentPrice = listing.installmentPrice;
        return installmentPrice;
    }

    // Function to remove/reset an address from approval
    function removeApproval(uint256 tokenId) internal {
        Listing storage listing = listings[tokenId];
        IERC721(listing.nftAddress).approve(address(0), tokenId);
    }

    // Function to revert the NFT back to the original owner if a payment is missed
    // removes approval
    function revertNFT(uint256 tokenId) internal view {
        Listing storage listing = listings[tokenId];
        // Check that a payment is overdue by seeing if current time is greater than time limit
        if (block.timestamp > installmentTimeLimit) {
            revert InstallmentOverdue();
        }
        // operator is set to false
        IERC721(listing.nftAddress).isApprovedForAll(
            listing.seller,
            msg.sender
        ) == false;
    }

     /// RECEIVE FUNCTION ///

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
      return this.onERC721Received.selector;
    }
}