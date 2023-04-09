// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Agreement} from  "src/Agreement.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";
import {IAgreementFactory} from "src/interfaces/IAgreementFactory.sol";

contract AgreementTest is Test {
    
    AgreementFactory public factoryContract;
    Agreement public newAgreement;

    address public owner; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 expected
    address public Alice;
    address public Bob;
    address public Charles;
    uint public expiry;

    struct MessageParams {
        uint24 section;     ///@dev Main Section index
        uint24 subSection;  ///@dev Sub Section index
        bytes32 body;       ///@dev Sub Section Message
    }


    /// @notice An unordered array of hashes used as keys pointing to messages
    /// ex. messageIndex[0] = _someMessageHash;
    bytes32[] private messageIndex;
    /// @notice mapping to query entire section of agreement
    mapping(uint24 => Message[]) private Sections;

    //This must be declared in every input;
    // Is this possible to Fuzz test???
    // MessageParams[] public exploitInput = [{
    //     section: 1,
    //     subSection: 1,
    //     body: "This is exploit message 1.1"
    // },{
    //     section: 2,
    //     subSection: 1,
    //     body: "This is exploit message 2.1"
    // }];


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
        newAgreement = factory.createContract(Alice, Bob, expiry);

        initializeAgreement();
    }


    /**
     *  Current solidity verion <=0.8.13 do not support initialization of 
     *      arrays of structs. Modifications must be made at run time. 
     */
    function initAgreement() internal {
        //Hash message before storage
        //create a nested array of agreement messages
        for(uint i; i < 5; ++i){
            for(uint j; j<2; ++j){
                Sections[_message.section].push(
                    Message({
                        section: _message.section,
                        subSection: _message.subSection,
                        body: _message.body,
                        index: i
                }));                
            }
        }
        MessageParams[] memory inputMessage = new MessageParams [{
                section: 1,
                subSection: 1,
                body: ""
            },{
                section: 1,
                subSection: 2,
                body: "This is test message 1.2"
            },{
                section: 2,
                subSection: 1,
                body: "This is test message 2.1"
            },{
                section: 3,
                subSection: 1,
                body: "This is test message 3.1"
            }]
            
            messageIndex.push(_message.body);
            



        //Store message
        inputAgreement = newAgreement.initialize( hashMessage(inputMessage) );
    }

    /**
     * Reinitialization should fail
     */
     function testRejectReInit() external {
        assertEq(Bob, Alice);
     }

    /**
     * Initialization can only be done by partyA or partyB
     */
    function textReject3rdPartInit() external {
        assertEq(Bob, Alice);
    }

    /**
     * [util]
     * @notice hash the message offline before storage on contract to reduce contract storage
     *  and gas prices
     * @notice online hasing is computationally expensive, best to do offline;
     */
    function hashMessage(MessageParams[] memory _messages) internal returns (_messages) { 
        uint len = _messages.length;
        for(uint i; i < messages.length; ++i){
            _messages[i].body = keccak256(abi.encodePacked(_body));        
        }
    }


    //================== [AGREEMENT TESTS] ==================
    
    /**
     * NEW AGREEMENT CONTRACT DEPLOYMENT TESTS
     */
    function testNewAgreementState() public {
        //party A is Alice
        assertEq(newAgreement.partyA(), Alice, "not partyA")
        //party B is Bob
        assertEq(newAgreement.partyB(), Bob, "not partyB")
        //not signed A 
        assertEq(approvedA, 1, "invalid approval");
        //not signed B
        assertEq(approvedB, 1, "invalid approval");
        //not verified
        assertEq(verified, 1, "invalid verification");
    }


    /**
     * @expect the agreement should be retrivable irregardless of which party 
     *  is input first to retrive index
     */
    function testNewAgreementRetrieval() public {
        address _agreement1 = getAgreement[Alice][Bob][expiry];
        address _agreement2 = getAgreement[Bob][Alice][expiry];
        assertEq(_agreement1, _agreement2, "not equal")
    }

    

    /**
     * The structure of an input message should match the format
     *  Message[{ Section: uint24, SubSection:uint24, body:bytes32, index: uint256 }, {...}, {...},] 
     * Fuzz testing?
     */
    function testMessageStructure() public {

    }

    function testRetrieveSection() public {

    }

    /**
     * @expect this method to fail when accessed by !partyA || !partyB
     */
    function testRejectRetrieveSection() public {

    }

    function testRetriveSingleMessage() public {

    }

    /**
     * @expect this method to fail when accessed by !partyA || !partyB
     */
    function testRejectRetrieveSingleMessage() public {

    }



}
