// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {AgreementFactory} from  "../src/AgreementFactory.sol";

contract AgreementScript is Script {
    
    function setUp() public {}

    function run() public {
        // broadcast single call 
        vm.broadcast();
        //Deploy Token
        new AgreementFactory();
    }
}
