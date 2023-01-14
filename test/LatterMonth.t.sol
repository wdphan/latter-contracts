// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {LatterMonth} from "src/LatterMonth.sol";
import {ILatterMonth} from "src/ILatterMonth.sol";
import {MyNFT} from "src/MyNFT.sol";

contract LatterTest is Test {
    
    LatterMonth public latter;
    MyNFT public nft;
    LatterTest public test;

    address bob = vm.addr(111);
    address bill = vm.addr(222);
    address owner = vm.addr(333);

    receive() external payable {}

    function setUp() public {
        latter = new LatterMonth(owner);
        nft = new MyNFT();

        vm.label(bob, "BOB");
        vm.deal(bob, 100 ether);

        vm.label(bill, "BILL");
        vm.deal(bill, 100 ether);

        vm.label(owner, "OWNER");
        vm.deal(owner, 100 ether);

        vm.deal(address(this), 100 ether);
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
        latter.listItem(address(nft), 1, 100);
    }

    //edit
    function testDeleteListing() public {
         // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // list item
        vm.prank(bob);
        latter.listItem(address(nft), 1, 100);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        vm.prank(address(bob));
        nft.approve(address(latter), 1);
        vm.prank(address(test));
        latter.deleteListing(1);
        
    }

    function testMakePayment() public {
        // bob mint token
        vm.prank(bob);
        nft.safeMint(bob, 1);

        // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);

        // execute contract
        latter.listItem(address(nft), 1, 100);

        // // bob approves latter contract
        vm.prank(bob);
        nft.approve(address(latter), 1);
        vm.prank(bill);
        latter.makePayment{value: 1 ether}(1, 1);
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