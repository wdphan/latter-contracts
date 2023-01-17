// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Timers.sol";
import "src/interface/ILatterMonth.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

/// @title Latter Month
/// @author William Phan
/// @notice Monthly payment model. Buyer decides how many Months/Installments.
/// @dev All function calls are currently implemented without side effects
/// @custom:experimental This is an experimental contract.

// Set the contract to be owned
contract LatterMonth is ILatterMonth, IERC721Receiver{
    using Timers for Timers.Timestamp;
    using Counters for Counters.Counter;

    // Timer to track the expiration of an action or event
    Timers.Timestamp public timer;

    // counts the number of listings - also the listingId, starts from 1
    Counters.Counter public listingCounter;

    // counts the number of sold listings
    Counters.Counter private listingSoldCounter;

    // The ERC721 token contract
    IERC721 public nftContract;

    // The address of the marketplace contract owner
    address public marketplaceOwner;

    // The marketplace transaction fee (0.5%)
    uint256 public transactionFee = msg.value * 5 / 100;

    mapping(uint256 => Listing) private listings;

    // The constructor with settings
    constructor(address _marketplaceOwner) {
        marketplaceOwner = _marketplaceOwner;
    }

    // Fallback function is called when msg.data is not empty
    // done so contract can receive ether
    fallback() external payable {}

     // Function to list an NFT for sale
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 listingPrice
    ) external {

        IERC721 nft = IERC721(nftAddress);

        // increment listing counter
        listingCounter.increment();

        // current incremented token listing
        Listing storage listing = listings[tokenId];

        // price to list cannot be negaive
        if (listingPrice <= 0) {
            revert PriceBelowZero();
        }

        // check if token isn't already listed
        if (listing.state != State.ForSale) {
            revert TokenAlreadyListed();
        }

        // inputs for new listing
        Listing memory newListing = Listing(
            false,
            0,
            tokenId,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            0,
            0,
            block.timestamp,
            // changes the state to for sale
            State.ForSale
        );

        // set new listing
        listings[tokenId] = newListing;

          // emit event
        emit ListingCreated(
            false,
            0,
            tokenId,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            0,
            0,
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
    function makePayment(uint256 tokenId, uint8 numberOfMonths) external payable {

        Listing storage listing = listings[tokenId];

        // Calculate the transaction fee 5%
        uint256 fee = msg.value * transactionFee;

        listing.installmentPrice = listing.listingPrice / numberOfMonths;

        // calculate installment plus marketplace fee of .05%
        uint256 totalInstallment = listing.installmentPrice + fee;

        // increase deadline of 14 days until next installment
        uint deadline = block.timestamp + 4 weeks;
        // for struct
        uint256 timeLeft = deadline - block.timestamp;
        // set the timeleft in the struct
        listing.timeLeft = timeLeft;

        //// REVERTS ////

        // just use the base plan
        if (numberOfMonths < 3) {
            revert SwitchPlans();
        }

        // checks if payment is past deadline
        // if so, send NFT back to seller
        if (block.timestamp > listing.timeLeft) {
            // send original owner NFT back
            IERC721(listing.nftAddress).safeTransferFrom(
                address(this),
                listing.seller,
                listing.tokenId
            );
            // send the value received back to msg.sender
            payable(msg.sender).transfer(msg.value);
            // emit listing expired
            emit ListingExpired(
                true,
                listing.installmentNumber,
                listing.tokenId,
                listing.nftAddress,
                listing.seller,
                listing.buyer,
                timeLeft,
                State.NotForSale
            );
        }

        // Check that the correct payment amount is received
        // if less, then revert
        // installmentPrice + the transaction fee
        if (msg.value < totalInstallment) {
            revert InsufficientInstallmentAmountPlusFee();
        }

        else if (
            listing.state == State.NotForSale
        ) {
            revert NotForSale();
        }
        // checks if installment number is greater than 1 to see
        // if there was not an existing buyer
        // otherwise revert
        else if (listing.installmentNumber > 1 && msg.sender != listing.buyer) {
            revert NotCurrentBuyer();
        }

        // check if initial buyer is msg.sender
        // check if installment number is between not less than 1 and not greater than 4
        else if (listing.installmentNumber > 4){
            revert AlreadyPaidOff();
        }

        ////  NON-REVERTS ////

        // set the buyer for first installment
        else if (listing.installmentNumber == 0) {
            listing.buyer = payable(msg.sender);
            // set payment active
            listing.state = State.PaymentActive;
            // Increment the number of installment payments made
            listing.installmentNumber++;
        }
        // if between 1 and 4 installments
        else if(listing.installmentNumber > 1 || listing.installmentNumber < 4) {
            // Increment the number of installment payments made
            listing.installmentNumber++;
        }
        // Check if all 4 installment payments have been made
        // if so, transfer the NFT
        if (listing.installmentNumber == 4) {
            // change the listing state to NotForSale
            listing.state = State.NotForSale;
            // Transfer ownership of the NFT from the seller to the msg.sender
            IERC721(listing.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                listing.tokenId
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

        // transfers part of the value (calculated fee) that was sent to the marketplace
        payable(address(this)).transfer(fee);
        // transfers part of the value (calculated installmentPrice) that was sent to the seller
        payable(listing.seller).transfer(listing.installmentPrice);
    }

    //// VIEW FUNCTIONS ////

    function getListingCount() public view returns (uint256 listingCount) {
         return listingCounter.current();
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


    //// RECEIVE NFT FUNCTION ////

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
      return this.onERC721Received.selector;
    }
}