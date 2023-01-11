// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Timers.sol";

/// @title Latter
/// @author William Phan
/// @notice Pay-in-four model. 4 payments made every 2 weeks for an NFT
/// @dev All function calls are currently implemented without side effects
/// @custom:experimental This is an experimental contract.

// Set the contract to be owned
contract Latter is ILatter{
    using Timers for Timers.Timestamp;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Timer to track the expiration of an action or event
    Timers.Timestamp public timer;
    // counts the number of listings - also the listingId, starts from 1
    Counters.Counter private listingCounter;
    // counts the number of sold listings
    Counters.Counter private listingSoldCounter;

    // counts number of installments paid for listing
    Counters.Counter private listingInstallmentCounter;

    // The ERC721 token contract
    IERC721 public nftContract;

    // The address of the original owner of the NFT
    address public originalOwner;

    // The address of the marketplace contract
    address public marketplaceContract;

    // The address of the marketplace contract owner
    address public marketplaceOwner;

    // The due date for each payment
    uint256 public installmentTimeLimit;

    // The amount of the payment due every 2 weeks
    uint256 public installmentAmount;

    // The marketplace transaction fee (0.5%)
    uint256 public transactionFee = uint256(0.005 * 10**18);

    mapping(uint256 => Listing) private listings;

    // checks if address is valid
    mapping(uint256 => address) public approved;

    // checks if the listing has had one address approved already
    modifier onlyOneApproval(uint256 _tokenId) {
        require(
            approved[_tokenId] == address(0),
            "Only one approval is allowed"
        );
        _;
    }

    // The constructor with settings
    constructor(address _marketplaceOwner) {
        marketplaceOwner = _marketplaceOwner;
        marketplaceContract = address(this);
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
        // give Latter marketplace approval
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            // put this on another doc
            revert UserNotApproved();
        }

        // default increment when listing
        listingCounter.increment();
        uint256 listingId = listingCounter.current();

        Listing storage listing = listings[listingId];

        // installment price = listing price divided by 4
        uint256 installmentPrice = listing.listingPrice.div(4);

        // current installment counter = 0
        uint256 installmentCounter = listingInstallmentCounter.current();

        // inputs for new listing
        Listing memory newListing = Listing(
            listingId,
            tokenId,
            installmentCounter,
            false,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            block.timestamp,
            // changes the state to for sale
            State.ForSale
        );

        // emit event
        emit ListingCreated(
            listingId,
            tokenId,
            installmentCounter,
            false,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            block.timestamp,
            State.ForSale
        );
    }

    function deleteListing(uint256 listingId) external {
        // require valid token Id
        if(listingId <= listingCounter.current()) {
            revert IdNotValid();
        }
        // make sure caller is valid
        if(msg.sender == !listings[listingId].seller ||
                msg.sender == !marketplaceContract){
                    revert NotOperator();
                }
        // ensure listing is up for sale
        if (listings[listingId].state == !State.ForSale){
            revert NotForSale();
        }

        Listing storage listing = listings[listingId];
        // must be the owner
        if (IERC721(listing.nftAddress).ownerOf(listing.tokenId) == !msg.sender){
            revert NotNFTOwner();
        }
        // marketplace must be approved
        if (IERC721(listing.nftAddress).getApproved(listing.tokenId) == !marketplaceContract){
            revert UserNotApproved();
        }

        // change the current seller of listing to zero address
        listing.seller = payable(address(0));

        // change the state of listing to not for sale
        listing.state = State.NotForSale;

        // emit listing has been removed by reseting to default values and zero address
        emit ListingDeleted(
            listingId,
            listing.tokenId,
            listing.installmentNumber,
            // time set to expired
            true,
            listing.nftAddress,
            payable(address(0)),
            payable(address(0)),
            listing.listingPrice,
            listing.installmentPrice,
            block.timestamp,
            State.NotForSale
        );
    }

    // function to get the total installment amount due
    // installment + the transaction fee
    function installmentAmountPlusFee(uint256 listingId)
        public
        view
        returns (uint256)
    {
        Listing storage listing = listings[listingId];
        // calculate the transaction fee
        uint256 fee = listing.installmentPrice.mul(transactionFee);
        // add the transaction fee to the installment amount
        uint256 totalAmountDue = listings[listingId].installmentPrice.add(fee);
        return totalAmountDue;
    }

    // function to get the installment amount only without transaction fee
    function installmentAmountOnly(uint256 listingId)
        public
        view
        returns (uint256)
    {
        Listing storage listing = listings[listingId];
        // calculate the transaction fee
        uint256 installmentPrice = listing.installmentPrice;
        return installmentPrice;
    }

    // makes sure only one address is approved
    function approveAddress(uint256 listingId)
        internal
        onlyOneApproval(listingId)
    {
        Listing storage listing = listings[listingId];
        IERC721(listing.nftAddress).approve(msg.sender, listingId);
    }

    // Function to remove/reset an address from approval
    function removeApproval(uint256 listingId) internal {
        Listing storage listing = listings[listingId];
        IERC721(listing.nftAddress).approve(address(0), listingId);
    }

    // installment + marketplace fee of .05%
    // make sure first payer will stay the first payer until after late time
    function makePayment(uint256 listingId) public payable {
        Listing storage listing = listings[listingId];
        // approve the sole payer from here on out with approve internal function
        approveAddress(listingId);
        // Checks if the one sending in eth is approved to do so
        if ( IERC721(listing.nftAddress).isApprovedForAll(
                listing.seller,
                msg.sender
            ) == !true){
                revert UserNotApproved();
            }

        // Calculate the transaction fee
        uint256 fee = installmentAmount.mul(transactionFee);
        // Check that the correct payment amount is received
        // installmentPrice + the transaction fee
        if ( msg.value >= listing.installmentPrice.add(fee){
            revert IncorrectInstallmentAmount();
        }
        // change the state of the nft
        listing.state = State.PaymentActive;

        // transfers part of the value that was sent to the marketplace
        payable(marketplaceContract).transfer(fee);
        // transfers part of the value that was sent to the seller
        payable(listing.seller).transfer(listing.installmentPrice);

        // Increment the number of installment payments made
        listingInstallmentCounter.increment();

        timer.setDeadline(uint64(block.timestamp + 14 days));

        uint256 deadline = timer.getDeadline();
        uint256 timeLeft = deadline - block.timestamp;

        emit ListingInstallmentPaid(
            listingId,
            listing.tokenId,
            listing.installmentNumber,
            false,
            listing.nftAddress,
            listing.seller,
            payable(msg.sender),
            listing.listingPrice,
            listing.installmentPrice,
            timeLeft,
            State.NotForSale
        );

        // Check if all 4 installment payments have been made
        // if so, transfer the NFT
        if (listingInstallmentCounter.current() == 4) {
            // change the listing state to NotForSale
            listing.state = State.NotForSale;
            // Transfer ownership of the NFT from the seller to the msg.sender
            IERC721(listing.nftAddress).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId
            );

            emit PaidOff(
                listingId,
                listing.tokenId,
                listing.installmentNumber,
                // time set to expired
                true,
                listing.nftAddress,
                // 0 address
                payable(address(0)),
                // 0 address
                payable(address(0)),
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
            listingInstallmentCounter.current() <= 4
        ) {
            revertNFT(listing.listingId);
        }
    }

    // Function to revert the NFT back to the original owner if a payment is missed
    // removes approval
    function revertNFT(uint256 listingId) internal view {
        Listing storage listing = listings[listingId];
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
}
