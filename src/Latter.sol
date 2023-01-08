// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Timers.sol";

// List and Sell NFTs
// include marketplace fee
// include installment amount
// include payment amount
// include time component and expiry

// Set the contract to be owned
contract Latter {
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

    enum State {
        ForSale,
        PaymentActive,
        NotForSale
    }

    // The ERC721 token contract
    IERC721 public nftContract;

    // The address of the original owner of the NFT
    address public originalOwner;

    // The address of the marketplace contract
    address public marketplaceContract;

    // The address of the marketplace contract
    address public marketplaceOwner;

    // The due date for each payment
    uint256 public installmentTimeLimit;

    // The amount of the payment due every 2 weeks
    uint256 public installmentAmount;

    // The marketplace transaction fee (0.5%)
    uint256 public transactionFee = uint256(0.005 * 10**18);

    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        address nftAddress;
        address payable seller;
        address payable buyer;
        uint256 listingPrice;
        uint256 installmentPrice;
        uint256 installmentNumber;
        // time left until next installment due
        uint256 timeLeft;
        bool isExpired;
        State state;
    }

    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        uint256 installmentNumber,
        // time left until next installment due
        uint256 timeLeft,
        bool isExpired,
        State state
    );

    event ListingInstallmentPaid(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        uint256 installmentNumber,
        // time left until next installment due
        uint256 timeLeft,
        bool isExpired,
        State state
    );

    event PaidOff(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        uint256 installmentNumber,
        // time left until next installment due
        uint256 timeLeft,
        bool isExpired,
        State state
    );

    event ListingDeleted(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        uint256 installmentNumber,
        // time left until next installment due
        uint256 timeLeft,
        bool isExpired,
        State state
    );

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
            revert("Price must be above 0");
        }
        // give Latter marketplace approval
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            // put this on another doc
            revert("This user is not approved for the marketplace.");
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
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            installmentCounter,
            block.timestamp,
            false,
            // changes the state to for sale
            State.ForSale
        );

        // emit event
        emit ListingCreated(
            listingId,
            tokenId,
            nftAddress,
            payable(msg.sender),
            payable(address(0)),
            listingPrice,
            installmentPrice,
            installmentCounter,
            block.timestamp,
            false,
            State.ForSale
        );
    }

    function deleteListing(uint256 listingId) external {
        // require valid token Id
        require(listingId <= listingCounter.current(), "id not valid");
        // make sure caller is valid
        require(
            msg.sender == listings[listingId].seller ||
                msg.sender == marketplaceContract,
            "not NFT owner"
        );
        // ensure listing is up for sale
        require(listings[listingId].state == State.ForSale);

        Listing storage listing = listings[listingId];
        // must be the owner
        require(
            IERC721(listing.nftAddress).ownerOf(listing.tokenId) == msg.sender,
            "must be the owner"
        );
        // marketplace must be approved
        require(
            IERC721(listing.nftAddress).getApproved(listing.tokenId) ==
                marketplaceContract,
            "must be approved"
        );

        // change the current seller of listing to zero address
        listing.seller = payable(address(0));

        // change the state of listing to not for sale
        listing.state = State.NotForSale;

        // emit listing has been removed by reseting to default values and zero address
        emit ListingDeleted(
            listingId,
            listing.tokenId,
            listing.nftAddress,
            payable(address(0)),
            payable(address(0)),
            listing.listingPrice,
            listing.installmentPrice,
            listing.installmentNumber,
            block.timestamp,
            // set time to expired
            true,
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

    // sets the timer to 2 weeks from now
    // function setTimer() public {
    //     timer.setDeadline(uint64(block.timestamp + 14 days));
    // }

    //  function getDeadline(Timestamp memory timer) internal pure returns (uint64) {
    //     return timer._deadline;
    // }

    // get time left
    // function setTimer() public {
    //     timer.setDeadline(uint64(block.timestamp + 14 days));
    // }

    // installment + marketplace fee of .05%
    // make sure first payer will stay the first payer until after late time
    function makePayment(uint256 listingId) public payable {
        Listing storage listing = listings[listingId];
        // approve the sole payer from here on out with approve internal function
        approveAddress(listingId);
        // Checks if the one sending in eth is approved to do so
        require(
            IERC721(listing.nftAddress).isApprovedForAll(
                listing.seller,
                msg.sender
            ) == true,
            "must be approved"
        );

        // Calculate the transaction fee
        uint256 fee = installmentAmount.mul(transactionFee);
        // Check that the correct payment amount is received
        // installmentPrice + the transaction fee
        require(
            msg.value >= listing.installmentPrice.add(fee),
            "Incorrect installment amount"
        );

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
            listing.nftAddress,
            listing.seller,
            payable(msg.sender),
            listing.listingPrice,
            listing.installmentPrice,
            listing.installmentNumber,
            timeLeft,
            false,
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
                listing.nftAddress,
                // 0 address
                payable(address(0)),
                // 0 address
                payable(address(0)),
                listing.listingPrice,
                listing.installmentPrice,
                listing.installmentNumber,
                timeLeft,
                // time set to expired
                true,
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
        require(
            block.timestamp > installmentTimeLimit,
            "No payment is overdue"
        );
        // operator is set to false
        IERC721(listing.nftAddress).isApprovedForAll(
            listing.seller,
            msg.sender
        ) == false;
    }
}
