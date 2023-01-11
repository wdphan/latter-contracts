// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {Latter} from "src/Latter.sol";
import {ILatter} from "src/ILatter.sol";

contract LatterTest is Test {
    
    Latter latter;

    address bob = vm.addr(111);
    address bill = vm.addr(222);
    address joe = vm.addr(333);

    receive() external payable {}

    function setUp() public {
        sampleContract = new SampleContract();
    }

    function testFunc1() public {
        sampleContract.func1(1337);
    }

    function testFunc2() public {
        sampleContract.func2(1337);
    }
}
