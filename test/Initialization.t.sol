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
 * $ forge test --match-path test/Initialization.t.sol
 */
contract InitializationTest is Test {
    
    AgreementFactory public factoryContract;
    Agreement public newAgreement;

    address public owner; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 expected
    address public Alice;
    address public Bob;
    address public Charles;
    uint expiry;

    bytes32[] public messageIndex;
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

        //Create message in local Foundry Storage
        createMessage();
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
            for(uint24 j; j < 2; ++j){
                //Push message to inputMessage arary to intialize message to be sent to smart contract
                messageIndex.push(hashMessage( string.concat("This is message ", Strings.toString(i), ".", Strings.toString(j)) ));
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
     * expect message retrieved from contract message to match message sent to contract
     */
    function test_InitAgreementPartyA() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        assertEq(Alice, newAgreement.partyA());
        vm.prank(Alice);
        
        newAgreement.initialize(_input);
    }

    function test_InitAgreementPartyB() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        assertEq(Bob, newAgreement.partyB());
        vm.prank(Bob);
        
        newAgreement.initialize(_input);
    }

    /**
     * Initialization can only be done by partyA or partyB
     */
    function text_ExpectFail3rdPartInit() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Charles);
        vm.expectRevert();

        newAgreement.initialize(_input);
    }

    /**
     * Reinitialization should fail
     */
    function test_ExpectFailReInitPartyA() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;

        vm.startPrank(Alice);        
        newAgreement.initialize(_input);

        vm.expectRevert();
        newAgreement.initialize(_input);
    }

    /**
     * Reinitialization should fail
     */
    function test_ExpectFailReInitBothParties() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Alice);
        newAgreement.initialize(_input);

        vm.prank(Bob);
        vm.expectRevert();
        newAgreement.initialize(_input);
    }
    
    /**
     * NEW AGREEMENT CONTRACT DEPLOYMENT TESTS
     */
    function test_NewAgreementState() public {
        //party A is Alice
        assertEq(newAgreement.partyA(), Alice, "not partyA");
        //party B is Bob
        assertEq(newAgreement.partyB(), Bob, "not partyB");
        //not signed A 
        assertEq(newAgreement.approvedA(), 1, "invalid approval");
        //not signed B
        assertEq(newAgreement.approvedB(), 1, "invalid approval");
        //not verified
        assertEq(newAgreement.verified(), 1, "invalid verification");
    }

    /**
     * expect - the agreement should be retrivable irregardless of which party 
     *  is input first to retrive index
     */
    function test_RetrieveNewAgreement() public {
        address _agreement1 = factoryContract.getAgreement(Alice, Bob, expiry);
        address _agreement2 = factoryContract.getAgreement(Bob, Alice, expiry);
        assertFalse(_agreement1 == address(0));
        console.logAddress(_agreement1);
        assertFalse(_agreement2 == address(0));
        console.logAddress(_agreement2);
        assertEq(_agreement1, _agreement2, "not equal");
    }

    /**
     * The structure of an input message should match the format
     *  Message[{ Section: uint24, SubSection:uint24, body:bytes32, index: uint256 }, {...}, {...},] 
     * Fuzz testing?
     */

    function test_RetrieveSection(uint24 _section) public {
        vm.assume(_section < 5);

        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Alice);
        newAgreement.initialize(_input);

        //index         [0]         [1]         [2]         [3]         [4]         [5]
        //mapping => [Message{}, Message{}], [Message{}, Message{}], [Message{}, Message{}]

        //index             [0]         [1]       [n]
        ///this returns [Message{}, Message{}, ... {} ]
        IAgreementActions.Message[] memory section = newAgreement.getSection(_section);

        for (uint i; i < section.length; ++i) {
            ///messages are added in linear order, [0], [1], [2]
            ///index value of object points to order it was added,
            ///expect message to match message at index in inputMessage
            assertEq(section[i].section, _input[section[i].index].section);
            assertEq(section[i].subSection, _input[section[i].index].subSection);
            assertEq(section[i].body, _input[section[i].index].body);
            
            assertEq(section[i].body, messageIndex[section[i].index]);
        }
    }

    function test_RetriveSingleMessage() public {
        IAgreementActions.MessageParams[] memory _input = inputMessage;

        vm.prank(Alice);
        newAgreement.initialize(_input);

        IAgreementActions.Message memory msgOne = newAgreement.getMessage(0,0);
        assertEq(msgOne.section, _input[0].section);
        assertEq(msgOne.subSection, _input[0].subSection);
        assertEq(msgOne.body, _input[0].body);
    }
}
