// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ILatter {

    enum State {
        ForSale,
        PaymentActive,
        NotForSale
    }

    struct Listing {
            bool isExpired;
            uint256 installmentNumber;
            uint256 tokenId;
            address nftAddress;
            address payable seller;
            address payable buyer;
            uint256 listingPrice;
            uint256 installmentPrice;
            // time left until next installment due
            uint256 timeLeft;
            State state;
        }

     event ListingCreated(
        bool isExpired,
        uint256 installmentNumber,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        // time left until next installment due
        uint256 timeLeft,
        State state
    );

     event ListingInstallmentPaid(
        bool isExpired,
        uint256 installmentNumber,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        // time left until next installment due
        uint256 timeLeft,
        State state
    );

    event PaidOff(
        bool isExpired,
        uint256 installmentNumber,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        // time left until next installment due
        uint256 timeLeft,
        State state
    );

    event ListingDeleted(
        bool isExpired,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        uint256 time,
        State state
    );

    // price is below zero
    error PriceBelowZero();
    
    // user is not approved for the marketplace
    error UserNotApproved();

    // token already listed
    error TokenAlreadyListed();

    // // invalid tokenId
    // error IdNotValid();

    // caller not valid
    error NotOperator();

    // not for sale
    error NotForSale();

    // not NFT owner
    error NotNFTOwner();

    // incorrect installment amount
    error IncorrectInstallmentAmountPlusFee();

    // installment overdue - passed 2 week due date
    error InstallmentOverdue();

    // The address of the original owner of the NFT
    function originalOwner() external returns (address);

    // The address of the marketplace contract owner
    function marketplaceOwner() external returns (address);

    // The due date for each payment
    function installmentTimeLimit() external returns (uint);

    // The amount of the payment due every 2 weeks
    function installmentAmount() external returns (uint);

    // The marketplace transaction fee (0.5%)
    function transactionFee() external returns (uint);

    // mapping of current listings
    // function listings() external returns (
    //  bool isExpired,
    //         uint256 installmentNumber,
    //         uint256 tokenId,
    //         address nftAddress,
    //         address payable seller,
    //         address payable buyer,
    //         uint256 listingPrice,
    //         uint256 installmentPrice,
    //         // time left until next installment due
    //         uint256 timeLeft,
    //         State state);
    
    // Function to list an NFT for sale
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 listingPrice
    ) external;

    function deleteListing(address nftAddress, uint256 tokenId) external;

    function getInstallmentAmountPlusFee(uint256 listingId) external returns (uint256);

    function getInstallmentAmountOnly(uint256 listingId) external returns (uint256);

    function makePayment(uint256 tokenId) external payable;
}