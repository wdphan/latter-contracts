// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ILatter {

    enum State {
        ForSale,
        PaymentActive,
        NotForSale
    }

    struct Listing {
            uint16 listingId;
            uint16 tokenId;
            uint8 installmentNumber;
            bool isExpired;
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
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        uint8 installmentNumber,
        // time left until next installment due
        uint256 timeLeft,
        bool isExpired,
        State state
    );

     event ListingInstallmentPaid(
        uint16 indexed listingId,
        uint16 indexed tokenId,
        bool isExpired,
        uint8 installmentNumber,
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
        uint16 indexed listingId,
        uint16 indexed tokenId,
        uint8 installmentNumber,
        bool isExpired,
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
        uint16 indexed listingId,
        uint16 indexed tokenId,
        uint8 installmentNumber,
        bool isExpired,
        address indexed nftAddress,
        address payable seller,
        address payable buyer,
        uint256 listingPrice,
        uint256 installmentPrice,
        // time left until next installment due
        uint256 timeLeft,
        State state
    );

    // The address of the original owner of the NFT
    function originalOwner() external returns (address);

    // The address of the marketplace contract
    function marketplaceContract() external returns (address);

    // The address of the marketplace contract owner
    function marketplaceOwner() external returns (address);

    // The due date for each payment
    function installmentTimeLimit() external returns (uint);

    // The amount of the payment due every 2 weeks
    function installmentAmount() external returns (uint);

    // The marketplace transaction fee (0.5%)
    function transactionFee() external returns (uint);

    // mapping of current listings
    function listings() external returns (uint16 listingId,
    uint16 tokenId, 
    uint8 installmentNumber, 
    bool isExpired, 
    address nftAddress, 
    address payable seller, 
    address payable buyer, 
    uint256 listingPrice, 
    uint256 installmentPrice,
    // time left until next installment due
    uint256 timeLeft,
    State state);
    
    // checks if address is valid with id
    function approved() external returns (address);
    
    // Function to list an NFT for sale
    function listItem() external;

    function deleteListing () external;

    function installmentAmountPlusFee(uint256 listingId) external returns (uint256);

    function installmentAmountOnly(uint256 listingId) external returns (uint256);

    function makePayment() external;
}