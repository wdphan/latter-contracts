// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {LatterBase} from "src/LatterBase.sol";
import {ILatterBase} from "src/interface/ILatterBase.sol";
import {MyNFT} from "src/MyNFT.sol";

contract LatterBaseTest is Test {
    
    LatterBase public latter;
    MyNFT public nft;
    LatterBaseTest public test;

    address bob = vm.addr(111);
    address bill = vm.addr(222);
    address owner = vm.addr(333);

    receive() external payable {}

    function setUp() public {
        latter = new LatterBase(owner);
        nft = new MyNFT();

        vm.label(bob, "BOB");
        vm.deal(bob, 100 ether);

        vm.label(bill, "BILL");
        vm.deal(bill, 100 ether);

        vm.label(owner, "OWNER");
    }

   function testMint() public {
        nft.safeMint(bob, 1);
        nft.safeMint(bob, 2);
    }

    function testFailMint() public {
        nft.safeMint(bob, 1);
        nft.safeMint(bob, 1);
    }

    function testListItem() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // execute contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);
    }

    function testFailListItemZeroPrice() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // execute contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 0);
    }

    function testFailListItemAlreadyListed() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // execute contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 0);

        // execute contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 0);
    }


   function testDeleteListing() public {
      // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob lists item
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);
        assertEq(nft.balanceOf(address(latter)), 1);
        
        vm.prank(bob);
        latter.deleteListing(1);
    }

   function testFailDeleteListingNotSeller() public {
      // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob lists item
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);
        assertEq(nft.balanceOf(address(latter)), 1);
        
        vm.prank(bill);
        latter.deleteListing(1);
    }

   function testFailDeleteListingAlreadyDeleted() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob lists item
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);
        assertEq(nft.balanceOf(address(latter)), 1);
        
        vm.prank(bill);
        latter.deleteListing(1);

        vm.prank(bill);
        latter.deleteListing(1);
    }

   function testFullPayment() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);

        // bill makes payment
        vm.startPrank(bill);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        
        // assert contract has transferred NFT to buyer
        assertEq(nft.balanceOf(address(latter)), 0);
    }


    function testPaymentNotInTime() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);

        // bill makes payment
        vm.startPrank(bill);
        latter.makePayment{value: 1 ether}(1);
        // 1 week overdue
        vm.warp(3 weeks);
        latter.makePayment{value: 1 ether}(1);

        // assert contract has transferred NFT back to buyer
        assertEq(nft.balanceOf(bob), 1);
        // assert bill got his msg.value back, excluding gas
        assertEq(address(bill).balance, 99000000000000000000);
    }
    
    function testFailPaymentWithInsufficientAmount() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 1 ether);

        // bill makes payment
        vm.startPrank(bill);
        latter.makePayment{value: .05 ether}(1);
    }

    function testFailNotCurrentBuyer() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 1 ether);

        // bill makes payment
        vm.prank(bill);
        latter.makePayment{value: 1 ether}(1);

        // bob makes payment right after
        vm.prank(bob);
        vm.expectRevert();
        latter.makePayment{value: 1 ether}(1);
    }

    function functionTestPaidOverFourInstallments () public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        vm.prank(bob);
        latter.listItem(address(nft), 1, 1 ether);

        // bill makes payment
        vm.startPrank(bill);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        vm.warp(1 weeks);
        latter.makePayment{value: 1 ether}(1);
        vm.expectRevert();
        latter.makePayment{value: 1 ether}(1);
    }


    function testGetListingCount() public {
        // bob mint token
        vm.startPrank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        nft.approve(address(latter), 1);

        // bob approves and executes contract
        latter.listItem(address(nft), 1, 100);

        assertEq(latter.getListingCount(), 1);
    }

    function testFailGetListingCount() public {
        vm.expectRevert();
        assertEq(latter.getListingCount(), 1);
    }


    function testGetInstallmentPlusFee() public {
         // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);
        
        latter.getInstallmentAmountPlusFee(1);
    }

    function testGetInstallmentAmountOnly() public {
         // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        latter.getInstallmentAmountOnly(1);
    }
}