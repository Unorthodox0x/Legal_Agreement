// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Agreement} from  "src/Agreement.sol";
import {IAgreementActions} from "src/interfaces/Agreement/IAgreementActions.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";
import {IAgreementFactory} from "src/interfaces/IAgreementFactory.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/** 
 * Run this Test
 * $ forge test --match-path test/Approval.t.sol
 */
contract ApprovalTest is Test {
    
    AgreementFactory public factoryContract;
    Agreement public newAgreement;

    address public owner; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 expected
    address public Alice;
    address public Bob;
    address public Charles;
    uint expiry;
    
    IAgreementActions.MessageParams[] public inputMessage;

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

        createMessage();
        initAgreement();
    }

    function initAgreement() internal {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Alice);

        //Store message
        newAgreement.initialize(_input);
    }

    /**
     * [util]
     * @notice hash the message offline before storage on contract to reduce contract storage
     *  and gas prices
     * @notice online hasing is computationally expensive, best to do offline;
     */
    function hashMessage(string memory _body) internal pure returns (bytes32) { 
        return keccak256(abi.encodePacked(_body));
    }

    /**
     *  Current solidity verion <=0.8.13 do not support initialization of 
     *      arrays of structs.
     * 
     *  Instead initialize an empty MessageParams array in Foundry State memory, 
     *    and push this message struct to smart contract to update state.
     *    in contract memory.  
     */
    function createMessage() public {
        for(uint24 i; i < 5; ++i){
            for(uint24 j; j <= 2; ++j){
                //Push message to inputMessage arary to intialize message to be sent to smart contract
                inputMessage.push(                
                    IAgreementActions.MessageParams({
                        section: i,
                        subSection: j,
                        //Hash message before storage
                        body: hashMessage( string.concat("This is message ", Strings.toString(i), ".", Strings.toString(j)) )
                    })
                );
            }
        }
    }

    /**
     * expect - contract state approvedA updated to true
     * expect - contract state approvedB unchanged
     */
    function test_ApproveA() public {
        vm.prank(Alice);
        newAgreement.approve();
     
        assertEq(newAgreement.approvedA(), 2);
        assertEq(newAgreement.approvedB(), 1);
    }

    /**
     * expect - contract state approvedB updated to true
     * expect - contract state approvedA unchanged
     */
    function test_ApproveB() public {
        vm.prank(Bob);
        newAgreement.approve();
     
        assertEq(newAgreement.approvedB(), 2);
        assertEq(newAgreement.approvedA(), 1);
    }

    /**
     * 3rd party attempts to approve contract by inputting address of contract partyA
     * expect - reverty onlySigner
     */
    function test_reject3rdPartyApprove(address _party3) public {
        vm.assume(_party3 != Alice && _party3 != Bob);
    
        vm.prank(_party3);
        vm.expectRevert(bytes(""));
        newAgreement.approve();
    }


    function test_RejectReApproveA() public {
        vm.startPrank(Alice);
        newAgreement.approve();

        vm.expectRevert(bytes(""));
        newAgreement.approve();
    }

    function test_RejectReApproveB() public {
        vm.startPrank(Bob);
        newAgreement.approve();

        vm.expectRevert(bytes(""));
        newAgreement.approve();
    }

    function test_ContractValidation() public {
        
        vm.prank(Alice);
        newAgreement.approve();
        assertEq(newAgreement.approvedA(), 2);
        assertEq(newAgreement.approvedB(), 1);
        assertEq(newAgreement.verified(), 1);

        vm.prank(Bob);
        newAgreement.approve();
        assertEq(newAgreement.approvedA(), 2);
        assertEq(newAgreement.approvedB(), 2);
        assertEq(newAgreement.verified(), 2);
    }
}
