// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Agreement} from  "src/Agreement.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";
import {IAgreementFactory} from "src/interfaces/IAgreementFactory.sol";

/** 
 * Run this Test
 * $ forge test --match-path test/Ownership.t.sol
 */
contract OwnershipTest is Test {
    
    AgreementFactory public factoryContract;
    Agreement public newAgreement;
    
    //EVENTS TO TEST
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event ContractCreated(address indexed partyA, address indexed partyB, uint256 indexed expiry, address agreement);

    address public owner; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 expected
    address public Alice;
    address public Bob;
    address public Charles;
    uint public expiry;


    /**
     * Testing of initializing may require separate scenarioes and thus
     *  separate test files with their own setUp context
     */
    function setUp() public {
        expiry = block.timestamp + 2000; //set static for uniform testing

        owner = msg.sender;
        Alice = makeAddr("Alice");
        Bob = makeAddr("Bob");
        Charles = makeAddr("Charles");
        
        //guarantees factory owner address
        vm.prank(owner);
        factoryContract = new AgreementFactory();
        address _agreement = factoryContract.createContract(Alice, Bob, expiry);
        newAgreement = Agreement(_agreement);
        //TODO TEST EVENT
        // emit factoryContract.ContractCreated(Alice, Bob, expiry, newAgreement);
        // vm.expectEmit(true, true, true, true, address(newAgreement));

    }

    //================== [FACTORY TESTS] ==================
 
    /**
     * FACTORY OWNERSHIP TESTS
     */
    function testOwner() public {
        console.log('owner', owner);
        console.log('factory owner', factoryContract.owner());
        assertEq(factoryContract.owner(), owner, "not owner");
    }

    /**
     * expect - The owner to be changed from original 'owner' in setup to Bob
     * expect - The OwnerChanged event to be exmitted from the factoryContract
     */
    function testOwnerChange() public {
        //ensure call comes from owner
        vm.prank(owner);

        vm.expectEmit(true, true, false, true, address(factoryContract));
        emit OwnerChanged(address(owner), Bob);

        factoryContract.setOwner(Bob);
        assertEq(factoryContract.owner(), Bob, "not owner");

    }

    function testDenyOwnerChange() public {
        vm.prank(Bob);
        vm.expectRevert();
        // vm.expectRevert(bytes(""));
        factoryContract.setOwner(Bob);

    }

    //================== [AGREEMENT TESTS] ==================
    /**
     * expect - the agreement should be retrivable irregardless of which party 
     *  is input first to retrive index
     */
    function testNewAgreementExists() public {
        address _agreement1 = factoryContract.getAgreement(Alice, Bob, expiry);
        address _agreement2 = factoryContract.getAgreement(Bob, Alice, expiry);
        assertEq(_agreement1, _agreement2, "not equal");
    }
}
