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
 * $ forge test --match-path test/PauseAgreement.t.sol
 */
contract PauseAgreementTest is Test {
    
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
        initAgreement();
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

    function initAgreement() internal {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Alice);

        //Store message
        newAgreement.initialize(_input);
    }


    /**
     * expect - after newAgreement.manageReviewStatus() called by partyA
     *  newAgreement.pauseA() == 2
     *  pauseB() still unchanged; 
     */
    function test_pauseAlice() public {
        vm.startPrank(Alice);
        newAgreement.manageReviewStatus();

        // first call pauses for partyA
        assertEq(newAgreement.pauseA(), 2);
        assertEq(newAgreement.pauseB(), 1);
        
        // second call unpauses for partyA
        newAgreement.manageReviewStatus();
        assertEq(newAgreement.pauseA(), 1);
        assertEq(newAgreement.pauseB(), 1);
    }

    function test_pauseBoB() public {
        vm.startPrank(Bob);
        newAgreement.manageReviewStatus();

        // first call pauses for partyA
        assertEq(newAgreement.pauseA(), 1);
        assertEq(newAgreement.pauseB(), 2);
        
        // second call unpauses for partyA
        newAgreement.manageReviewStatus();
        assertEq(newAgreement.pauseA(), 1);
        assertEq(newAgreement.pauseB(), 1);
    }

    function test_pauseBoth() public {        
        // pause for partyA
        vm.prank(Alice);
        newAgreement.manageReviewStatus();
        assertEq(newAgreement.pauseA(), 2);
        assertEq(newAgreement.pauseB(), 1);

        //pause for partyB
        vm.prank(Bob);
        newAgreement.manageReviewStatus();
        assertEq(newAgreement.pauseA(), 2);
        assertEq(newAgreement.pauseB(), 2);
    }


    /**
     * expect - partyA should not be able to add message once paused by partyA
     */
    function test_RejectPauseAaddA(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        messageIndex.push(_msgHash);
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: _msgHash
        });

        vm.startPrank(Alice);
        newAgreement.manageReviewStatus();
        
        //Attempt Add by Alice
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - partyB should not be able to add once paused by partyA
     */
    function test_RejectPauseAaddB(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        messageIndex.push(_msgHash);
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: _msgHash
        });

        vm.prank(Alice);
        newAgreement.manageReviewStatus();
        
        //Attempt Add by Bob
        vm.prank(Bob);
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - partyA should not be able to add once paused by partyB
     */
    function test_RejectPauseBAddA(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        messageIndex.push(_msgHash);
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: _msgHash
        });

        vm.prank(Bob);
        newAgreement.manageReviewStatus();

        //Attempt Add by Alice
        vm.prank(Alice);
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - partyB should not be able to add once paused by partyB
     */
    function test_RejectPauseBAddB(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        messageIndex.push(_msgHash);
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: _msgHash
        });

        vm.startPrank(Bob);
        newAgreement.manageReviewStatus();
        //Attempt Add by Bob
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - No modification to agreement once paused by either party
     */
    function test_RejectPauseUpdate(uint24 _section, uint24 _subSection) public {
        vm.assume(_section < 5);
        vm.assume(_subSection == 0);

        //fetch message before update
        IAgreementActions.Message memory _oldMsg = newAgreement.getMessage(_section, _subSection);

        //Create new message to update existing msg in messageIndex
        bytes32 _updatedMsgHash = hashMessage( string.concat("This is updated message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        
        messageIndex[_oldMsg.index] = _updatedMsgHash;

        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _oldMsg.section, //puts new message at old message index
            subSection: _oldMsg.subSection, //puts new message at old message index
            body: _updatedMsgHash //message to update
        });

        vm.startPrank(Alice);
        newAgreement.manageReviewStatus();
        vm.expectRevert(bytes(""));
        newAgreement.updateMessage(newMsg);
    }

    /**
     * expect - No modification to agreement once paused by either party
     */
    function test_RejectPauseRemove(uint24 _section, uint24 _subSection) public {
         //test remove any message added during initialization
        vm.assume(_section < 5);
        vm.assume (_subSection <= 1);

        IAgreementActions.MessageParams memory _toRemove = IAgreementActions.MessageParams({
            section: _section, //puts new message at old message index
            subSection: _subSection, //puts new message at old message index
            body: hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)))
        });

        //REMOVE
        vm.startPrank(Alice);
        newAgreement.manageReviewStatus();
        vm.expectRevert(bytes(""));
        newAgreement.remove(_toRemove);
    }
}